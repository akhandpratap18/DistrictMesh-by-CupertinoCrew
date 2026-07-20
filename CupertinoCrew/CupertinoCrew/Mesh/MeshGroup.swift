import Foundation

/// A group replica held locally by every member (Phase 6).
///
/// Groups are eventually-consistent: each member keeps its own `MeshGroup` copy,
/// kept in sync by flooding small control packets over the existing mesh. The admin
/// (the creator) is authoritative for destructive operations (delete / remove) and for
/// full-membership `groupSync` snapshots. Codable so the whole replica can be shipped
/// in a `groupSync` payload.
struct MeshGroup: Codable, Identifiable, Equatable {
	let id: UUID
	var name: String
	/// Stable peer ID of the creator. Only this peer may delete the group or remove members.
	let adminPeerID: String
	/// Stable peer IDs of current members (includes the admin). A Set makes membership
	/// idempotent — re-adding an existing member is a no-op, so duplicate members are
	/// structurally impossible.
	var members: Set<String>
	let createdAt: Date

	init(id: UUID = UUID(), name: String, adminPeerID: String, members: Set<String>, createdAt: Date = Date()) {
		self.id = id
		self.name = name
		self.adminPeerID = adminPeerID
		self.members = members
		self.createdAt = createdAt
	}

	func isAdmin(_ peerID: String) -> Bool { peerID == adminPeerID }
	func contains(_ peerID: String) -> Bool { members.contains(peerID) }
}

// MARK: - Group control payloads
//
// Each is the `payload` of a MeshPacket whose `type` names the operation and whose
// `groupID` carries the group's UUID string. They are plain Codable value types — the
// transport/relay layer never inspects them; only GroupManager on member devices does.

/// `groupInvite` — offer membership to `invitedPeerID`. Carries enough to build a
/// replica on accept without a prior sync (`groupName`, `adminPeerID`).
struct GroupInvitePayload: Codable, Equatable {
	let groupID: UUID
	let groupName: String
	let adminPeerID: String
	let invitedPeerID: String
	let invitedBy: String
}

/// `groupAccept` — `memberPeerID` accepted an invite and is now a member (a.k.a. join).
struct GroupAcceptPayload: Codable, Equatable {
	let groupID: UUID
	let memberPeerID: String
}

/// `groupDecline` — `invitedPeerID` declined a pending invite.
struct GroupDeclinePayload: Codable, Equatable {
	let groupID: UUID
	let invitedPeerID: String
}

/// `groupLeave` — `memberPeerID` voluntarily left the group.
struct GroupLeavePayload: Codable, Equatable {
	let groupID: UUID
	let memberPeerID: String
}

/// `groupDelete` — admin dissolved the group. Honored only if `adminPeerID` matches
/// the replica's known admin.
struct GroupDeletePayload: Codable, Equatable {
	let groupID: UUID
	let adminPeerID: String
}

/// `groupRemove` — admin evicted `removedPeerID`. Honored only if `adminPeerID` matches.
struct GroupRemovePayload: Codable, Equatable {
	let groupID: UUID
	let adminPeerID: String
	let removedPeerID: String
}

/// `groupSync` — authoritative full-membership snapshot for convergence.
struct GroupSyncPayload: Codable, Equatable {
	let group: MeshGroup
}

/// A membership invitation this device has received and not yet answered.
struct GroupInvite: Identifiable, Equatable {
	let groupID: UUID
	let groupName: String
	let adminPeerID: String
	let invitedBy: String
	var id: UUID { groupID }
}
