import Foundation

enum MeshPriority: Int, Codable, Comparable, CaseIterable {
	case normal = 0
	case high = 1
	case emergency = 2

	static func < (lhs: MeshPriority, rhs: MeshPriority) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}

/// Packet type system (Phase 5). Existing cases keep their original raw values so
/// packets serialized by Phase 1–4 builds still decode byte-for-byte. New cases are
/// additive scaffolding — the transport/bus treat all types uniformly (flood + dedup +
/// TTL) except `.ack`, which the bus consumes for acknowledgement tracking. Feature
/// logic for groups/payments/discovery is intentionally NOT implemented here.
///
/// Spec vocabulary → case mapping:
///   TEXT → text · HEARTBEAT → heartbeat · ACK → ack · GROUP_INVITE → groupInvite
///   GROUP_ACCEPT → groupAccept · GROUP_LEAVE → groupLeave · DISCOVERY → discovery
///   PAYMENT → payment · PAYMENT_CONFIRMATION → paymentConfirmation · SYSTEM → system
enum MeshMessageType: String, Codable {
	// --- Existing (Phase 1–4) — raw values frozen for wire compatibility ---
	case ping
	case emergencyAlert
	case emergencyCancel
	case surplusAlert
	case surplusClaim
	case walletVoucher
	case compassPairing
	case compassRange

	// --- Phase 5 additions (protocol scaffolding only) ---
	case text
	case heartbeat
	case ack
	case groupInvite
	case groupAccept
	case groupLeave
	case groupDecline
	case groupDelete
	case groupRemove
	case groupSync
	case discovery
	case payment
	case paymentConfirmation
	case system

	// --- Location tracking (additive; same-build fleet, so wire-safe) ---
	case locationBeacon
}

/// Payload carried by an `.ack` packet: the id of the packet being acknowledged.
/// Kept as a dedicated Codable so ACK plumbing never has to parse free-form payloads.
struct AckPayload: Codable, Equatable {
	let acknowledgedPacketID: UUID
}

/// A single mesh packet. Carries everything the store-and-forward bus needs
/// (unique ID, priority, TTL/hop budget, optional addressing) independent of what's
/// inside `payload`.
///
/// Phase 5 evolution: the type was renamed `MeshMessage` → `MeshPacket` and gained
/// optional addressing fields (`previousHopPeerID`, `destinationPeerID`, `groupID`).
/// All original stored properties keep their names, so the JSON wire format is a
/// superset of the old one: the new fields are `Optional` and encode via
/// `encodeIfPresent` (omitted when nil), and decode via `decodeIfPresent` (absent →
/// nil). Old builds ignore the unknown keys; new builds tolerate their absence — so
/// packets flow both directions across a mixed fleet without breaking forwarding.
struct MeshPacket: Codable, Identifiable, Equatable {
	let id: UUID
	let type: MeshMessageType
	let priority: MeshPriority
	let originPeerID: String
	let createdAt: Date
	let validUntil: Date
	var hopCount: Int
	let maxHops: Int
	let payload: Data

	// --- Phase 5 optional addressing (additive, wire-compatible) ---
	/// Stable ID of the peer we received this packet directly from on the last hop.
	/// nil on a freshly originated packet; set by the relayer on each forward.
	var previousHopPeerID: String?
	/// Optional unicast destination. nil = broadcast/flood to everyone (legacy behavior).
	/// When set and it matches the local peer, the bus treats the packet as delivered
	/// to its final destination and emits an ACK.
	let destinationPeerID: String?
	/// Optional group scope for future group features. Carried but not interpreted yet.
	let groupID: String?

	init(
		id: UUID = UUID(),
		type: MeshMessageType,
		priority: MeshPriority,
		originPeerID: String,
		createdAt: Date = Date(),
		validFor: TimeInterval,
		hopCount: Int = 0,
		maxHops: Int = 6,
		payload: Data,
		previousHopPeerID: String? = nil,
		destinationPeerID: String? = nil,
		groupID: String? = nil
	) {
		self.id = id
		self.type = type
		self.priority = priority
		self.originPeerID = originPeerID
		self.createdAt = createdAt
		self.validUntil = createdAt.addingTimeInterval(validFor)
		self.hopCount = hopCount
		self.maxHops = maxHops
		self.payload = payload
		self.previousHopPeerID = previousHopPeerID
		self.destinationPeerID = destinationPeerID
		self.groupID = groupID
	}

	// MARK: - Phase 5 vocabulary aliases
	// Read-only convenience names requested by the Phase 5 spec, mapped onto the
	// existing stored properties so the wire format (JSON keys) is unchanged.
	var packetID: UUID { id }
	var sourcePeerID: String { originPeerID }
	var packetType: MeshMessageType { type }
	var timestamp: Date { createdAt }

	var isExpired: Bool {
		Date() > validUntil || hopCount >= maxHops
	}

	/// True when this packet carries a unicast destination this bus should ACK once
	/// it is delivered locally (and is not itself an ACK, to avoid ack-of-ack storms).
	func isAddressed(to localPeerID: String) -> Bool {
		type != .ack && destinationPeerID == localPeerID
	}

	/// Copy with hop count incremented exactly once and the previous-hop stamp updated,
	/// for re-broadcast. This is the ONLY place hopCount is mutated on relay, which
	/// guarantees "increment exactly once per relay" (see MessageBus.handleIncoming).
	func relayed(previousHop: String? = nil) -> MeshPacket {
		var copy = self
		copy.hopCount += 1
		copy.previousHopPeerID = previousHop ?? copy.previousHopPeerID
		return copy
	}
}

/// Source-compatibility alias: pre-Phase-5 code (and the diagnostics UI) refers to
/// `MeshMessage`. The type is now `MeshPacket`; this alias keeps every call site
/// compiling without change. The struct name never appears on the wire (JSON keys do),
/// so this rename is invisible to other devices.
typealias MeshMessage = MeshPacket

extension MeshPacket {
	/// Diagnostic pings are for verifying connectivity during setup/testing, not payloads
	/// that should linger — keep their TTL short so repeated test taps self-clean quickly
	/// instead of polluting the store-and-forward backlog at the normal 300s TTL.
	static let pingTTL: TimeInterval = 45

	/// ACK packets are transient control traffic; short TTL keeps them from lingering
	/// in the store-and-forward backlog after the round trip completes or times out.
	static let ackTTL: TimeInterval = 30
}
