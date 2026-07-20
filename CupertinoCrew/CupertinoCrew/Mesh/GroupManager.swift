import Foundation
import Combine

/// The mesh capabilities GroupManager needs, and nothing else. MessageBus conforms to
/// this. Decoupling here keeps GroupManager from touching the transport or routing at
/// all (it only originates packets and consumes already-relayed inbound ones), and lets
/// the group logic be unit-tested against a fake channel with no MultipeerConnectivity.
@MainActor
protocol GroupPacketChannel: AnyObject {
	/// Stable local peer identity used as group admin/member ID.
	var localPeerID: String { get }
	/// Every accepted (deduped, non-expired) inbound packet — already relayed by the bus.
	var groupInbox: AnyPublisher<MeshPacket, Never> { get }
	/// Originate a packet onto the mesh (floods + store-and-forwards like any other).
	func send(_ packet: MeshPacket)
}

/// Owns group membership state on top of the mesh (Phase 6).
///
/// Design invariants:
/// - It NEVER relays. The bus relays every packet regardless of group membership
///   (multi-hop preserved); GroupManager only reacts to packets the bus delivers to
///   `groupInbox`, and only mutates local state — non-members simply ignore the payload.
/// - Membership is a `Set<String>`, so duplicate members are impossible.
/// - The admin (creator) is authoritative for delete/remove and for `groupSync` snapshots;
///   those inbound ops are honored only when the packet's stated admin matches the
///   replica's known admin (transport is untrusted by design — see SRD trust model; real
///   signing is deferred, see agents.md TODOs).
///
/// Group control packets flood as ordinary broadcasts (no unicast `destinationPeerID`),
/// so they do not engage the Phase 5 ACK path — the accept/decline packets are the
/// application-level acknowledgement of an invite.
@MainActor
final class GroupManager: ObservableObject {
	/// Group replicas this device is a member of (or, for the admin, owns), keyed by id.
	@Published private(set) var groups: [UUID: MeshGroup] = [:]
	/// Invites received and awaiting this device's accept/decline, keyed by group id.
	@Published private(set) var receivedInvites: [UUID: GroupInvite] = [:]

	/// Invitees known to have an outstanding (unanswered) invite per group. Used to reject
	/// duplicate invites; not part of the synced replica.
	private var pendingInvitees: [UUID: Set<String>] = [:]

	private let channel: GroupPacketChannel
	private var cancellable: AnyCancellable?

	/// Local peer identity (group admin/member ID).
	var localPeerID: String { channel.localPeerID }

	/// Groups TTL — long enough to store-and-forward to late joiners within a session.
	private static let groupTTL: TimeInterval = 300

	init(channel: GroupPacketChannel) {
		self.channel = channel
		cancellable = channel.groupInbox
			.sink { [weak self] packet in self?.handleInbound(packet) }
	}

	// MARK: - Read helpers

	func group(_ id: UUID) -> MeshGroup? { groups[id] }
	func isMember(of id: UUID) -> Bool { groups[id]?.contains(localPeerID) ?? false }
	func isAdmin(of id: UUID) -> Bool { groups[id]?.isAdmin(localPeerID) ?? false }
	var myGroups: [MeshGroup] { Array(groups.values) }

	// MARK: - Operations (return false on any invalid operation)

	/// Create a group locally. Admin = this device. No packet until the first invite.
	@discardableResult
	func createGroup(name: String) -> MeshGroup {
		let group = MeshGroup(name: name, adminPeerID: localPeerID, members: [localPeerID])
		groups[group.id] = group
		return group
	}

	/// Invite a peer. Any member may invite. Rejects self-invite, duplicate member,
	/// duplicate invite, and non-member/unknown-group callers.
	@discardableResult
	func inviteMember(_ invitee: String, to groupID: UUID) -> Bool {
		guard let group = groups[groupID], group.contains(localPeerID) else { return false }
		guard invitee != localPeerID else { return false }               // no self-invite
		guard !group.contains(invitee) else { return false }             // no duplicate member
		guard !(pendingInvitees[groupID]?.contains(invitee) ?? false) else { return false } // no duplicate invite
		pendingInvitees[groupID, default: []].insert(invitee)
		emit(.groupInvite, groupID: groupID, payload: GroupInvitePayload(
			groupID: groupID, groupName: group.name, adminPeerID: group.adminPeerID,
			invitedPeerID: invitee, invitedBy: localPeerID))
		return true
	}

	/// Accept a pending invite (this is how a peer joins). Builds/updates the local replica
	/// and announces membership; the admin will re-sync the authoritative roster.
	@discardableResult
	func acceptInvite(_ groupID: UUID) -> Bool {
		guard let invite = receivedInvites[groupID] else { return false }
		guard !(groups[groupID]?.contains(localPeerID) ?? false) else { return false }
		if groups[groupID] != nil {
			groups[groupID]?.members.insert(localPeerID)
		} else {
			// Best-known replica from the invite; membership converges via groupSync.
			groups[groupID] = MeshGroup(id: groupID, name: invite.groupName,
				adminPeerID: invite.adminPeerID, members: [invite.adminPeerID, localPeerID])
		}
		receivedInvites[groupID] = nil
		emit(.groupAccept, groupID: groupID, payload: GroupAcceptPayload(groupID: groupID, memberPeerID: localPeerID))
		return true
	}

	/// Explicit join alias — a pending invite is required (join == accept in this model).
	@discardableResult
	func joinGroup(_ groupID: UUID) -> Bool { acceptInvite(groupID) }

	/// Decline a pending invite.
	@discardableResult
	func declineInvite(_ groupID: UUID) -> Bool {
		guard receivedInvites[groupID] != nil else { return false }
		receivedInvites[groupID] = nil
		emit(.groupDecline, groupID: groupID, payload: GroupDeclinePayload(groupID: groupID, invitedPeerID: localPeerID))
		return true
	}

	/// Leave a group this device belongs to. Drops the local replica.
	@discardableResult
	func leaveGroup(_ groupID: UUID) -> Bool {
		guard let group = groups[groupID], group.contains(localPeerID) else { return false }
		groups[groupID] = nil
		pendingInvitees[groupID] = nil
		emit(.groupLeave, groupID: groupID, payload: GroupLeavePayload(groupID: groupID, memberPeerID: localPeerID))
		return true
	}

	/// Delete a group — admin only. Dissolves it for everyone.
	@discardableResult
	func deleteGroup(_ groupID: UUID) -> Bool {
		guard let group = groups[groupID], group.isAdmin(localPeerID) else { return false }
		groups[groupID] = nil
		pendingInvitees[groupID] = nil
		emit(.groupDelete, groupID: groupID, payload: GroupDeletePayload(groupID: groupID, adminPeerID: localPeerID))
		return true
	}

	/// Remove a member — admin only. Admin cannot remove itself (use delete/leave).
	@discardableResult
	func removeMember(_ member: String, from groupID: UUID) -> Bool {
		guard let group = groups[groupID], group.isAdmin(localPeerID) else { return false }
		guard member != localPeerID else { return false }
		guard group.contains(member) else { return false }
		groups[groupID]?.members.remove(member)
		pendingInvitees[groupID]?.remove(member)
		emit(.groupRemove, groupID: groupID, payload: GroupRemovePayload(groupID: groupID, adminPeerID: localPeerID, removedPeerID: member))
		synchronizeGroup(groupID) // admin pushes the authoritative roster
		return true
	}

	/// Broadcast the full membership snapshot for convergence. Any member may call it.
	@discardableResult
	func synchronizeGroup(_ groupID: UUID) -> Bool {
		guard let group = groups[groupID], group.contains(localPeerID) else { return false }
		emit(.groupSync, groupID: groupID, payload: GroupSyncPayload(group: group))
		return true
	}

	// MARK: - Inbound handling
	//
	// The bus has already relayed this packet. We only update local state, and only when
	// the packet is relevant to a group we belong to (or an invite addressed to us).

	private func handleInbound(_ packet: MeshPacket) {
		switch packet.type {
		case .groupInvite:  decode(packet, as: GroupInvitePayload.self, handleInvite)
		case .groupAccept:  decode(packet, as: GroupAcceptPayload.self, handleAccept)
		case .groupDecline: decode(packet, as: GroupDeclinePayload.self, handleDecline)
		case .groupLeave:   decode(packet, as: GroupLeavePayload.self, handleLeave)
		case .groupDelete:  decode(packet, as: GroupDeletePayload.self, handleDelete)
		case .groupRemove:  decode(packet, as: GroupRemovePayload.self, handleRemove)
		case .groupSync:    decode(packet, as: GroupSyncPayload.self, handleSync)
		default: return // not a group packet — nothing to process (it was still relayed)
		}
	}

	private func handleInvite(_ p: GroupInvitePayload) {
		// Members track the pending invitee (for admin/member visibility + dup suppression).
		if groups[p.groupID]?.contains(localPeerID) == true {
			pendingInvitees[p.groupID, default: []].insert(p.invitedPeerID)
		}
		guard p.invitedPeerID == localPeerID else { return }        // not for us → ignore payload
		guard groups[p.groupID]?.contains(localPeerID) != true else { return } // already a member
		guard receivedInvites[p.groupID] == nil else { return }     // duplicate invite → ignore
		receivedInvites[p.groupID] = GroupInvite(groupID: p.groupID, groupName: p.groupName,
			adminPeerID: p.adminPeerID, invitedBy: p.invitedBy)
	}

	private func handleAccept(_ p: GroupAcceptPayload) {
		guard groups[p.groupID] != nil else { return } // we don't know this group → not ours
		groups[p.groupID]?.members.insert(p.memberPeerID) // Set → dedup
		pendingInvitees[p.groupID]?.remove(p.memberPeerID)
		if groups[p.groupID]?.isAdmin(localPeerID) == true {
			synchronizeGroup(p.groupID) // admin converges the roster for everyone
		}
	}

	private func handleDecline(_ p: GroupDeclinePayload) {
		pendingInvitees[p.groupID]?.remove(p.invitedPeerID)
	}

	private func handleLeave(_ p: GroupLeavePayload) {
		guard groups[p.groupID] != nil else { return }
		groups[p.groupID]?.members.remove(p.memberPeerID)
		pendingInvitees[p.groupID]?.remove(p.memberPeerID)
	}

	private func handleDelete(_ p: GroupDeletePayload) {
		// Only the real admin can dissolve the group.
		guard let group = groups[p.groupID], group.isAdmin(p.adminPeerID) else { return }
		groups[p.groupID] = nil
		receivedInvites[p.groupID] = nil
		pendingInvitees[p.groupID] = nil
	}

	private func handleRemove(_ p: GroupRemovePayload) {
		guard let group = groups[p.groupID], group.isAdmin(p.adminPeerID) else { return }
		if p.removedPeerID == localPeerID {
			groups[p.groupID] = nil // we were evicted → drop our replica
		} else {
			groups[p.groupID]?.members.remove(p.removedPeerID)
		}
		pendingInvitees[p.groupID]?.remove(p.removedPeerID)
	}

	private func handleSync(_ p: GroupSyncPayload) {
		let snap = p.group
		// Accept only from the group's authoritative admin (or first time we learn it).
		if let existing = groups[snap.id], existing.adminPeerID != snap.adminPeerID { return }
		if snap.contains(localPeerID) {
			groups[snap.id] = snap
		} else if groups[snap.id] != nil {
			groups[snap.id] = nil // authoritative roster no longer includes us
		}
	}

	// MARK: - Plumbing

	private func decode<T: Decodable>(_ packet: MeshPacket, as: T.Type, _ body: (T) -> Void) {
		guard let value = try? JSONDecoder().decode(T.self, from: packet.payload) else { return }
		body(value)
	}

	private func emit<T: Encodable>(_ type: MeshMessageType, groupID: UUID, payload: T) {
		guard let data = try? JSONEncoder().encode(payload) else { return }
		let packet = MeshPacket(
			type: type, priority: .normal, originPeerID: localPeerID,
			validFor: Self.groupTTL, payload: data, groupID: groupID.uuidString)
		channel.send(packet)
	}
}
