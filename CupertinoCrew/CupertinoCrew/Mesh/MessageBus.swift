import Foundation
import Combine

/// Store-and-forward message bus sitting above MeshTransport.
/// Owns: unique-ID dedup, priority-ordered send, TTL/hop expiry,
/// local persistence, and re-broadcast to peers that join later.
@MainActor
final class MessageBus: ObservableObject, GroupPacketChannel {
	@Published private(set) var peerCount: Int = 0
	@Published private(set) var isOnline: Bool = false // always false: no internet path exists in this app
	/// True once advertising+browsing are active (mirrors transport.isRunningPublisher), so the
	/// UI can distinguish "still searching" from "not started" while peerCount == 0.
	@Published private(set) var isRunning: Bool = false
	/// Recent accepted messages, newest first — backs the diagnostics screen (FR-MESH-10).
	@Published private(set) var receivedLog: [MeshMessage] = []

	/// Live protocol counters (Phase 5). Read-only to callers; mutated only here on @MainActor.
	@Published private(set) var stats = MeshStats()

	/// Live list of connected peer stable IDs, mirrored from the transport for dashboard data.
	@Published private(set) var connectedPeerIDs: [String] = []

	/// Fan-out of every accepted (deduped, non-expired) message, for feature layers to filter by type.
	let inbox = PassthroughSubject<MeshMessage, Never>()

	// MARK: - GroupPacketChannel conformance (Phase 6)
	// Read-only surface GroupManager consumes. Does not change routing: `groupInbox` is the
	// existing post-relay `inbox`, and `send` is the existing origin path.
	var localPeerID: String { transport.localPeerID }
	var groupInbox: AnyPublisher<MeshMessage, Never> { inbox.eraseToAnyPublisher() }

	private let transport: MeshTransport
	private var seenIDs: Set<UUID> = []
	private var store: [MeshMessage] = [] // persisted backlog, still-valid messages only
	private var cancellables = Set<AnyCancellable>()
	private var backlogTasks: [String: Task<Void, Never>] = [:]
	private var backlogTaskTokens: [String: UUID] = [:]
	private let diagnosticsSessionID = UUID().uuidString

	// MARK: - ACK infrastructure (Phase 5)
	// Establishes acknowledgement tracking only. Automatic retries are intentionally
	// NOT implemented in this phase — a timed-out packet is recorded, not resent.

	/// One outbound packet awaiting acknowledgement from its destination.
	private struct PendingAck {
		let packetID: UUID
		let destinationPeerID: String
		let sentAt: Date
		let timeoutTask: Task<Void, Never>
	}

	/// Directed packets this device sent that are still awaiting an ACK, keyed by packet id.
	private var pendingAcks: [UUID: PendingAck] = [:]
	/// Packet ids this device sent that were acknowledged by their destination.
	private(set) var acknowledgedPacketIDs: Set<UUID> = []
	/// Packet ids whose ACK window elapsed with no acknowledgement (no retry is attempted).
	private(set) var timedOutPacketIDs: Set<UUID> = []
	/// How long to wait for an ACK before marking a pending packet timed out.
	private let ackTimeout: TimeInterval = 30

	/// Diagnostic pings self-clean via pingTTL, but also cap how many sit in the backlog at
	/// once so rapid repeated "Send test ping" taps can't pile up during connection testing.
	private let maxStoredPings = 5

	private func log(_ event: String, remotePeerID: String? = nil, fields: [String: String] = [:], function: String = #function, packetType: String = "unknown", packetSize: Int? = nil) {
		MeshDiagnostics.log(event, localPeerID: transport.localPeerID, remotePeerID: remotePeerID, sessionID: diagnosticsSessionID, fields: fields, function: function, packetType: packetType, packetSize: packetSize)
	}

	private let storeURL: URL = {
		let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		return dir.appendingPathComponent("mesh_message_store.json")
	}()
	private let seenIDsURL: URL = {
		let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		return dir.appendingPathComponent("mesh_seen_ids.json")
	}()

	init(transport: MeshTransport) {
		self.transport = transport
		loadPersisted()

		transport.peerCountPublisher
			.receive(on: DispatchQueue.main)
			.sink { [weak self] count in self?.peerCount = count }
			.store(in: &cancellables)

		transport.connectedPeerIDsPublisher
			.receive(on: DispatchQueue.main)
			.sink { [weak self] ids in self?.connectedPeerIDs = ids }
			.store(in: &cancellables)

		transport.isRunningPublisher
			.receive(on: DispatchQueue.main)
			.sink { [weak self] running in self?.isRunning = running }
			.store(in: &cancellables)

		transport.messageReceived
			.receive(on: DispatchQueue.main)
			.sink { [weak self] incoming in
				self?.log("actor_hop_enter", fields: ["destination": "main", "source": "MCSessionDelegate.didReceiveData"])
				defer { self?.log("actor_hop_exit", fields: ["destination": "main", "source": "MCSessionDelegate.didReceiveData"]) }
				self?.handleIncoming(incoming.data)
			}
			.store(in: &cancellables)

		transport.peerConnected
			.receive(on: DispatchQueue.main)
			.sink { [weak self] peerID in self?.sendBacklog(to: peerID) }
			.store(in: &cancellables)
	}

	deinit {
		backlogTasks.values.forEach { $0.cancel() }
		pendingAcks.values.forEach { $0.timeoutTask.cancel() }
	}

	func start() {
		log("message_bus_started")
		transport.start()
	}

	/// Originate a brand-new message from this device (emergency alert, voucher, etc).
	func send(_ message: MeshMessage) {
		guard accept(message) else { return }
		persist()
		stats.packetsSent += 1
		stats.markActivity()
		receivedLog.insert(message, at: 0) // local echo, independent of whether any peer is connected
		// ACK infrastructure: a directed, non-ACK packet expects an acknowledgement from
		// its destination. Register it as pending and arm a timeout (no auto-retry).
		if message.type != .ack, let destination = message.destinationPeerID {
			registerPendingAck(for: message, destination: destination)
		}
		broadcast(message)
	}

	// MARK: - Incoming

	private func handleIncoming(_ data: Data) {
		log("decode_started", fields: ["decoder": "MeshMessage"], packetSize: data.count)
		let message: MeshMessage
		do {
			message = try JSONDecoder().decode(MeshMessage.self, from: data)
			log("decode_succeeded", fields: ["decoder": "MeshMessage"], packetSize: data.count)
		} catch {
			log("decode_failed", fields: ["decoder": "MeshMessage", "error": error.localizedDescription], packetSize: data.count)
			log("packet_receive_rejected", fields: ["reason": "decode_failed", "error": error.localizedDescription], packetSize: data.count)
			return
		}
		log("packet_received", remotePeerID: message.originPeerID, fields: ["packetUUID": message.id.uuidString, "hopCount": "\(message.hopCount)"], packetType: message.type.rawValue, packetSize: data.count)
		// Diagnostics: every decoded inbound packet counts as received and feeds the
		// hop-count aggregate (average + maximum). hopCount here is the value AS RECEIVED,
		// before any relay increment — so the sample reflects the sender's stamp exactly.
		stats.packetsReceived += 1
		stats.recordHopCount(message.hopCount)
		stats.markActivity()
		guard accept(message) else { return } // dedup + expiry gate (FR-MESH-04, FR-MESH-06)
		persist()
		stats.packetsDelivered += 1
		receivedLog.insert(message, at: 0)
		inbox.send(message)

		// ACK infrastructure (Phase 5):
		if message.type == .ack {
			// An ACK addressed to us resolves one of our pending outbound packets.
			processIncomingAck(message)
		} else if message.isAddressed(to: transport.localPeerID) {
			// A directed packet reached its final destination (us) — acknowledge it.
			log("packet_delivered_to_destination", remotePeerID: message.sourcePeerID, fields: ["packetUUID": message.id.uuidString, "hopCount": "\(message.hopCount)"], packetType: message.type.rawValue)
			sendAck(for: message)
		}

		// Store-and-forward: relay on at higher hop count so multi-hop delivery works (FR-MESH-02).
		// hopCount is incremented exactly once, here, by MeshPacket.relayed() — the sole
		// mutation point on the relay path. previousHop is stamped with our local ID.
		let relayedMessage = message.relayed(previousHop: transport.localPeerID)
		guard !relayedMessage.isExpired else {
			// Hop/TTL budget exhausted by this relay — stop flooding (loop/storm bound).
			stats.packetsDropped += 1
			log("packet_dropped", remotePeerID: message.originPeerID, fields: ["reason": "hop_budget_exhausted", "packetUUID": message.id.uuidString, "hopCount": "\(relayedMessage.hopCount)", "maxHops": "\(relayedMessage.maxHops)"], packetType: message.type.rawValue)
			return
		}
		stats.packetsRelayed += 1
		log("packet_relay", remotePeerID: message.originPeerID, fields: ["packetUUID": message.id.uuidString, "hopCount": "\(relayedMessage.hopCount)", "previousHop": transport.localPeerID, "routingDestination": "all_connected_peers"], packetType: message.type.rawValue)
		broadcast(relayedMessage)
	}

	/// Returns true if this is a new, still-valid message worth keeping/relaying.
	@discardableResult
	private func accept(_ message: MeshMessage) -> Bool {
		guard !message.isExpired else {
			stats.packetsExpired += 1
			log("packet_dropped", remotePeerID: message.originPeerID, fields: ["reason": "expired", "packetUUID": message.id.uuidString, "hopCount": "\(message.hopCount)"], packetType: message.type.rawValue)
			return false
		}
		guard !seenIDs.contains(message.id) else {
			stats.duplicatePackets += 1
			log("duplicate_packet_dropped", remotePeerID: message.originPeerID, fields: ["packetUUID": message.id.uuidString, "hopCount": "\(message.hopCount)"], packetType: message.type.rawValue)
			return false
		}
		seenIDs.insert(message.id)
		store.append(message)
		pruneExpired()
		capPingBacklog()
		return true
	}

	private func pruneExpired() {
		store.removeAll { $0.isExpired }
	}

	/// Keeps only the most recent `maxStoredPings` ping messages in the backlog store.
	/// pingTTL already self-cleans within ~45s, this just bounds a burst of rapid taps
	/// from ballooning the backlog while connection testing is in progress.
	private func capPingBacklog() {
		let pings = store.filter { $0.type == .ping }.sorted { $0.createdAt > $1.createdAt }
		guard pings.count > maxStoredPings else { return }
		let idsToDrop = Set(pings.dropFirst(maxStoredPings).map { $0.id })
		store.removeAll { idsToDrop.contains($0.id) }
	}

	// MARK: - Outgoing / relay

	private func broadcast(_ message: MeshMessage) {
		guard let data = try? JSONEncoder().encode(message) else {
			stats.packetsDropped += 1
			log("packet_send_failed", fields: ["reason": "encode_failed", "packetUUID": message.id.uuidString], packetType: message.type.rawValue)
			return
		}
		log("packet_send_requested", remotePeerID: "all_connected_peers", fields: ["packetUUID": message.id.uuidString, "hopCount": "\(message.hopCount)"], packetType: message.type.rawValue, packetSize: data.count)
		do {
			try transport.broadcast(data)
		} catch {
			stats.packetsDropped += 1
			log("packet_send_failed", fields: ["packetUUID": message.id.uuidString, "error": error.localizedDescription], packetType: message.type.rawValue, packetSize: data.count)
		}
	}

	// MARK: - ACK infrastructure (Phase 5)
	// Establishes acknowledgement plumbing only: emit an ACK on delivery to a directed
	// destination, match inbound ACKs to pending outbound packets, and time pending
	// packets out. No automatic retransmission is performed — a timeout is recorded and
	// surfaced via `timedOutPacketIDs`, and a later phase decides retry policy.

	/// Track a directed outbound packet as awaiting acknowledgement and arm its timeout.
	private func registerPendingAck(for message: MeshMessage, destination: String) {
		pendingAcks[message.id]?.timeoutTask.cancel()
		let packetID = message.id
		let timeout = ackTimeout
		// Created inside a @MainActor method, so the task body is main-actor isolated.
		let timeoutTask = Task { [weak self] in
			try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
			guard !Task.isCancelled else { return }
			self?.ackTimedOut(packetID)
		}
		pendingAcks[packetID] = PendingAck(packetID: packetID, destinationPeerID: destination, sentAt: Date(), timeoutTask: timeoutTask)
		log("ack_pending", remotePeerID: destination, fields: ["packetUUID": packetID.uuidString, "timeoutSeconds": "\(Int(ackTimeout))"], packetType: message.type.rawValue)
	}

	/// Emit an ACK back toward the source of a directed packet we just delivered locally.
	private func sendAck(for message: MeshMessage) {
		let ackPayload = AckPayload(acknowledgedPacketID: message.id)
		guard let payloadData = try? JSONEncoder().encode(ackPayload) else {
			stats.packetsDropped += 1
			log("packet_send_failed", remotePeerID: message.sourcePeerID, fields: ["reason": "ack_encode_failed", "acknowledges": message.id.uuidString], packetType: "ack")
			return
		}
		let ack = MeshPacket(
			type: .ack,
			priority: message.priority,
			originPeerID: transport.localPeerID,
			validFor: MeshPacket.ackTTL,
			payload: payloadData,
			destinationPeerID: message.sourcePeerID
		)
		guard accept(ack) else { return }
		persist()
		stats.packetsSent += 1
		stats.markActivity()
		log("ack_sent", remotePeerID: message.sourcePeerID, fields: ["packetUUID": ack.id.uuidString, "acknowledges": message.id.uuidString])
		broadcast(ack)
	}

	/// Consume an inbound ACK addressed to us, resolving its pending outbound packet.
	/// ACKs not addressed to us are ignored here and simply relayed onward (flood).
	private func processIncomingAck(_ message: MeshMessage) {
		guard let payload = try? JSONDecoder().decode(AckPayload.self, from: message.payload) else {
			log("ack_decode_failed", remotePeerID: message.sourcePeerID, fields: ["packetUUID": message.id.uuidString])
			return
		}
		let ackedID = payload.acknowledgedPacketID
		guard message.destinationPeerID == transport.localPeerID,
			  let pending = pendingAcks.removeValue(forKey: ackedID) else { return }
		pending.timeoutTask.cancel()
		acknowledgedPacketIDs.insert(ackedID)
		timedOutPacketIDs.remove(ackedID)
		stats.packetsAcknowledged += 1
		stats.markActivity()
		log("ack_received", remotePeerID: message.sourcePeerID, fields: ["packetUUID": message.id.uuidString, "acknowledges": ackedID.uuidString])
	}

	/// Fired when a pending packet's ACK window elapses. Records the timeout; no retry.
	private func ackTimedOut(_ packetID: UUID) {
		guard let pending = pendingAcks.removeValue(forKey: packetID) else { return }
		guard !acknowledgedPacketIDs.contains(packetID) else { return }
		timedOutPacketIDs.insert(packetID)
		log("ack_timeout", remotePeerID: pending.destinationPeerID, fields: ["packetUUID": packetID.uuidString, "waitedSeconds": "\(Int(ackTimeout))"])
	}

	// MARK: - Dashboard data (Phase 5)

	/// Immutable snapshot for a future developer dashboard. No UI consumes it yet.
	var dashboard: MeshDashboardSnapshot {
		MeshDashboardSnapshot(
			connectedPeers: connectedPeerIDs,
			connectedPeerCount: peerCount,
			relayCount: stats.packetsRelayed,
			averageHopCount: stats.averageHopCount,
			maximumHopCount: stats.maximumHopCountSeen,
			pendingAckCount: pendingAcks.count,
			acknowledgedCount: acknowledgedPacketIDs.count,
			timedOutAckCount: timedOutPacketIDs.count,
			stats: stats,
			lastActivity: stats.lastActivity
		)
	}

	/// A device that joins/rejoins later still receives everything still valid (FR-MESH-03).
	/// Paced ~150ms apart rather than dumped all at once, so a large backlog doesn't saturate
	/// the link the moment a peer connects.
	private func sendBacklog(to peerID: String) {
		pruneExpired()
		let messages = store.sorted(by: { $0.priority > $1.priority })
		log("retry_queue", remotePeerID: peerID, fields: ["pendingCount": "\(messages.count)"])
		backlogTasks[peerID]?.cancel()
		backlogTasks[peerID] = nil
		backlogTaskTokens[peerID] = nil
		guard !messages.isEmpty else { return }
		let taskToken = UUID()
		backlogTaskTokens[peerID] = taskToken
		log("task_created", remotePeerID: peerID, fields: ["task": "sendBacklog", "messageCount": "\(messages.count)"])
		let task = Task { [weak self] in
			self?.log("task_entered", remotePeerID: peerID, fields: ["task": "sendBacklog"])
			defer {
				if let self, self.backlogTaskTokens[peerID] == taskToken {
					self.backlogTasks[peerID] = nil
					self.backlogTaskTokens[peerID] = nil
					self.log("task_exited", remotePeerID: peerID, fields: ["task": "sendBacklog"])
				}
			}
			for message in messages {
				guard let self else { return }
				guard !Task.isCancelled else {
					self.log("task_cancelled", remotePeerID: peerID, fields: ["task": "sendBacklog"])
					return
				}
				guard let data = try? JSONEncoder().encode(message) else { continue }
				do {
					try self.transport.send(data, to: peerID)
				} catch {
					self.log("packet_send_failed", remotePeerID: peerID, fields: ["packetUUID": message.id.uuidString, "error": error.localizedDescription])
				}
				do {
					try await Task.sleep(nanoseconds: 150_000_000)
				} catch {
					self.log("task_cancelled", remotePeerID: peerID, fields: ["task": "sendBacklog", "error": error.localizedDescription])
					return
				}
			}
		}
		backlogTasks[peerID] = task
	}

	// MARK: - Persistence

	private func persist() {
		pruneExpired()
		if let data = try? JSONEncoder().encode(store) {
			try? data.write(to: storeURL, options: .atomic)
		}
		if let data = try? JSONEncoder().encode(Array(seenIDs)) {
			try? data.write(to: seenIDsURL, options: .atomic)
		}
	}

	private func loadPersisted() {
		if let data = try? Data(contentsOf: storeURL) {
			log("decode_started", fields: ["decoder": "[MeshMessage]", "source": "message_store"], packetSize: data.count)
			do {
				let decoded = try JSONDecoder().decode([MeshMessage].self, from: data)
				store = decoded.filter { !$0.isExpired }
				log("decode_succeeded", fields: ["decoder": "[MeshMessage]", "source": "message_store"], packetSize: data.count)
			} catch {
				log("persistence_decode_failed", fields: ["source": "message_store", "error": error.localizedDescription], packetSize: data.count)
			}
		}
		if let data = try? Data(contentsOf: seenIDsURL) {
			log("decode_started", fields: ["decoder": "[UUID]", "source": "seen_ids"], packetSize: data.count)
			do {
				let decoded = try JSONDecoder().decode([UUID].self, from: data)
				seenIDs = Set(decoded)
				log("decode_succeeded", fields: ["decoder": "[UUID]", "source": "seen_ids"], packetSize: data.count)
			} catch {
				log("persistence_decode_failed", fields: ["source": "seen_ids", "error": error.localizedDescription], packetSize: data.count)
			}
		}
	}
}
