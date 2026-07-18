import Foundation

enum MeshPriority: Int, Codable, Comparable, CaseIterable {
	case normal = 0
	case high = 1
	case emergency = 2

	static func < (lhs: MeshPriority, rhs: MeshPriority) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}

enum MeshMessageType: String, Codable {
	case ping
	case emergencyAlert
	case emergencyCancel
	case surplusAlert
	case surplusClaim
	case walletVoucher
	case compassPairing
	case compassRange
}

/// A single mesh message. Carries everything the store-and-forward bus needs
/// (unique ID, priority, TTL/hop budget) independent of what's inside `payload`.
struct MeshMessage: Codable, Identifiable, Equatable {
	let id: UUID
	let type: MeshMessageType
	let priority: MeshPriority
	let originPeerID: String
	let createdAt: Date
	let validUntil: Date
	var hopCount: Int
	let maxHops: Int
	let payload: Data

	init(
		id: UUID = UUID(),
		type: MeshMessageType,
		priority: MeshPriority,
		originPeerID: String,
		createdAt: Date = Date(),
		validFor: TimeInterval,
		hopCount: Int = 0,
		maxHops: Int = 6,
		payload: Data
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
	}

	var isExpired: Bool {
		Date() > validUntil || hopCount >= maxHops
	}

	/// Copy with hop count incremented, for re-broadcast.
	func relayed() -> MeshMessage {
		var copy = self
		copy.hopCount += 1
		return copy
	}
}

extension MeshMessage {
	/// Diagnostic pings are for verifying connectivity during setup/testing, not payloads
	/// that should linger — keep their TTL short so repeated test taps self-clean quickly
	/// instead of polluting the store-and-forward backlog at the normal 300s TTL.
	static let pingTTL: TimeInterval = 45
}
