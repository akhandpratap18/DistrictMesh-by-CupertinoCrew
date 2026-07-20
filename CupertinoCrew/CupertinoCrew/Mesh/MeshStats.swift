import Foundation

/// Lightweight, in-memory mesh protocol counters (Phase 5).
///
/// Deliberately plain value type: mutated only on the `@MainActor` MessageBus, so no
/// locking is needed. All increments are O(1); the running hop-count aggregate avoids
/// storing per-packet history, keeping this cheap enough to update on every packet.
struct MeshStats: Equatable {
	/// Packets this device originated (via `MessageBus.send`, including ACKs it emits).
	var packetsSent = 0
	/// Packets decoded from a peer (every successfully deserialized inbound packet).
	var packetsReceived = 0
	/// Packets this device re-broadcast on behalf of another node (multi-hop relay).
	var packetsRelayed = 0
	/// Unique, non-expired packets accepted and delivered to the local inbox.
	var packetsDelivered = 0
	/// ACKs received that matched one of this device's pending outbound packets.
	var packetsAcknowledged = 0
	/// Inbound packets dropped because their TTL/hop budget was exhausted.
	var packetsExpired = 0
	/// Packets dropped for other reasons (encode/send failure, relay-time expiry).
	var packetsDropped = 0
	/// Inbound packets dropped because their id was already seen (loop/flood suppression).
	var duplicatePackets = 0

	/// Highest hop count observed on any inbound packet.
	var maximumHopCountSeen = 0
	/// Timestamp of the most recent protocol activity (send/receive/relay/ack).
	var lastActivity: Date?

	// Running aggregate for the average — kept private so callers can't desync it.
	private var hopCountSum = 0
	private var hopCountSamples = 0

	/// Mean hop count across every inbound packet sampled (0 when none seen yet).
	var averageHopCount: Double {
		hopCountSamples == 0 ? 0 : Double(hopCountSum) / Double(hopCountSamples)
	}

	/// Fold one inbound packet's hop count into the average/maximum aggregates.
	mutating func recordHopCount(_ hop: Int) {
		hopCountSum += hop
		hopCountSamples += 1
		if hop > maximumHopCountSeen { maximumHopCountSeen = hop }
	}

	/// Stamp the last-activity marker; call on any protocol event.
	mutating func markActivity(at date: Date = Date()) {
		lastActivity = date
	}
}

/// Immutable snapshot that a future developer dashboard (Phase 6+) can render directly.
/// No UI is built in Phase 5 — this only defines the shape of the data the bus exposes.
struct MeshDashboardSnapshot: Equatable {
	let connectedPeers: [String]
	let connectedPeerCount: Int
	let relayCount: Int
	let averageHopCount: Double
	let maximumHopCount: Int
	let pendingAckCount: Int
	let acknowledgedCount: Int
	let timedOutAckCount: Int
	let stats: MeshStats
	let lastActivity: Date?
}
