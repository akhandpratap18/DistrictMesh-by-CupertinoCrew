import Foundation
import Combine

/// Store-and-forward message bus sitting above MeshTransport.
/// Owns: unique-ID dedup, priority-ordered send, TTL/hop expiry,
/// local persistence, and re-broadcast to peers that join later.
@MainActor
final class MessageBus: ObservableObject {
	@Published private(set) var peerCount: Int = 0
	@Published private(set) var isOnline: Bool = false // always false: no internet path exists in this app
	/// True once advertising+browsing are active (mirrors transport.isRunningPublisher), so the
	/// UI can distinguish "still searching" from "not started" while peerCount == 0.
	@Published private(set) var isRunning: Bool = false
	/// Recent accepted messages, newest first — backs the diagnostics screen (FR-MESH-10).
	@Published private(set) var receivedLog: [MeshMessage] = []

	/// Fan-out of every accepted (deduped, non-expired) message, for feature layers to filter by type.
	let inbox = PassthroughSubject<MeshMessage, Never>()

	private let transport: MeshTransport
	private var seenIDs: Set<UUID> = []
	private var store: [MeshMessage] = [] // persisted backlog, still-valid messages only
	private var cancellables = Set<AnyCancellable>()
	private var backlogTasks: [String: Task<Void, Never>] = [:]
	private var backlogTaskTokens: [String: UUID] = [:]
	private let diagnosticsSessionID = UUID().uuidString

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
	}

	func start() {
		log("message_bus_started")
		transport.start()
	}

	/// Originate a brand-new message from this device (emergency alert, voucher, etc).
	func send(_ message: MeshMessage) {
		guard accept(message) else { return }
		persist()
		receivedLog.insert(message, at: 0) // local echo, independent of whether any peer is connected
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
		guard accept(message) else { return } // dedup + expiry gate (FR-MESH-04, FR-MESH-06)
		persist()
		receivedLog.insert(message, at: 0)
		inbox.send(message)
		// Store-and-forward: relay on at higher hop count so multi-hop delivery works (FR-MESH-02).
		let relayedMessage = message.relayed()
		log("packet_relay", remotePeerID: message.originPeerID, fields: ["packetUUID": message.id.uuidString, "hopCount": "\(relayedMessage.hopCount)", "routingDestination": "all_connected_peers"], packetType: message.type.rawValue)
		broadcast(relayedMessage)
	}

	/// Returns true if this is a new, still-valid message worth keeping/relaying.
	@discardableResult
	private func accept(_ message: MeshMessage) -> Bool {
		guard !message.isExpired else {
			log("packet_dropped", remotePeerID: message.originPeerID, fields: ["reason": "expired", "packetUUID": message.id.uuidString, "hopCount": "\(message.hopCount)"], packetType: message.type.rawValue)
			return false
		}
		guard !seenIDs.contains(message.id) else {
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
			log("packet_send_failed", fields: ["reason": "encode_failed", "packetUUID": message.id.uuidString], packetType: message.type.rawValue)
			return
		}
		log("packet_send_requested", remotePeerID: "all_connected_peers", fields: ["packetUUID": message.id.uuidString, "hopCount": "\(message.hopCount)"], packetType: message.type.rawValue, packetSize: data.count)
		do {
			try transport.broadcast(data)
		} catch {
			log("packet_send_failed", fields: ["packetUUID": message.id.uuidString, "error": error.localizedDescription], packetType: message.type.rawValue, packetSize: data.count)
		}
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
