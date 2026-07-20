// Phase 6 GroupManager correctness harness.
//
// Runs the real GroupManager against a fake in-memory mesh (each sent packet is delivered
// once to every OTHER node — modeling the flood outcome, matching the real bus where a
// sender's own packet never re-enters its inbox). No transport / MultipeerConnectivity /
// XCTest involved. Lives outside the Xcode synchronized group (not in the app target).
//
//   swiftc -parse-as-library \
//     CupertinoCrew/CupertinoCrew/Mesh/MeshMessage.swift \
//     CupertinoCrew/CupertinoCrew/Mesh/MeshGroup.swift \
//     CupertinoCrew/CupertinoCrew/Mesh/GroupManager.swift \
//     CupertinoCrew/Tests/GroupManagerTests.swift -o /tmp/grouptests && /tmp/grouptests

import Foundation
import Combine

private var failures = 0
private func check(_ cond: Bool, _ label: String) {
	if cond { print("  ok   \(label)") } else { failures += 1; print("  FAIL \(label)") }
}

@MainActor
final class FakeChannel: GroupPacketChannel {
	let localPeerID: String
	let inboundSubject = PassthroughSubject<MeshPacket, Never>()
	var groupInbox: AnyPublisher<MeshPacket, Never> { inboundSubject.eraseToAnyPublisher() }
	var onSend: ((MeshPacket) -> Void)?
	init(_ id: String) { localPeerID = id }
	func send(_ packet: MeshPacket) { onSend?(packet) }
}

@MainActor
final class FakeMesh {
	private var channels: [FakeChannel] = []
	func addNode(_ id: String) -> GroupManager {
		let ch = FakeChannel(id)
		ch.onSend = { [weak self] pkt in self?.deliver(pkt, from: id) }
		channels.append(ch)
		return GroupManager(channel: ch)
	}
	// Flood: every other node receives the packet exactly once.
	private func deliver(_ pkt: MeshPacket, from: String) {
		for ch in channels where ch.localPeerID != from { ch.inboundSubject.send(pkt) }
	}
}

@main
struct Runner {
	@MainActor
	static func main() {
		print("== Phase 6 GroupManager Tests ==")

		// --- Create + invite + accept (join) ---
		print("[create → invite → accept]")
		let mesh = FakeMesh()
		let a = mesh.addNode("A"); let b = mesh.addNode("B"); let c = mesh.addNode("C")
		let group = a.createGroup(name: "Squad")
		check(a.isAdmin(of: group.id), "creator is admin")
		check(a.isMember(of: group.id), "creator is a member")
		check(a.inviteMember("B", to: group.id), "invite B succeeds")
		check(b.receivedInvites[group.id] != nil, "B sees a pending invite")
		check(c.receivedInvites.isEmpty, "C (not invited) sees no invite")
		check(b.acceptInvite(group.id), "B accepts")
		check(a.group(group.id)?.members == ["A", "B"], "admin roster converges to {A,B}")
		check(b.group(group.id)?.members.contains("B") == true, "B replica includes B")
		check(b.group(group.id)?.members.contains("A") == true, "B replica includes admin A")
		check(b.receivedInvites[group.id] == nil, "B's invite cleared after accept")

		// --- Non-member relay/ignore ---
		print("[non-member ignores payload]")
		check(c.groups.isEmpty, "C relayed group traffic but stores NO group state")
		check(c.isMember(of: group.id) == false, "C is not a member")

		// --- Guard rails ---
		print("[guards: self / duplicate / invalid]")
		check(a.inviteMember("A", to: group.id) == false, "self-invite rejected")
		check(a.inviteMember("B", to: group.id) == false, "duplicate member invite rejected")
		check(a.inviteMember("C", to: group.id), "first invite to C succeeds")
		check(a.inviteMember("C", to: group.id) == false, "duplicate pending invite rejected")
		check(c.acceptInvite(UUID()) == false, "accept with no invite rejected")
		check(b.deleteGroup(group.id) == false, "non-admin delete rejected")
		check(b.removeMember("A", from: group.id) == false, "non-admin remove rejected")
		check(a.removeMember("A", from: group.id) == false, "admin cannot remove itself")
		check(b.leaveGroup(UUID()) == false, "leave unknown group rejected")

		// --- Decline ---
		print("[decline]")
		check(c.declineInvite(group.id), "C declines its pending invite")
		check(c.receivedInvites[group.id] == nil, "C invite cleared after decline")
		check(a.group(group.id)?.members.contains("C") == false, "declining C never joined")

		// --- Sync convergence with a third member ---
		print("[membership sync]")
		check(a.inviteMember("C", to: group.id), "re-invite C")
		check(c.acceptInvite(group.id), "C joins")
		check(a.group(group.id)?.members == ["A", "B", "C"], "admin roster {A,B,C}")
		check(b.group(group.id)?.members == ["A", "B", "C"], "B converged to {A,B,C} via sync")
		check(c.group(group.id)?.members == ["A", "B", "C"], "C converged to {A,B,C} via sync")

		// --- Remove member (admin) ---
		print("[admin remove member]")
		check(a.removeMember("C", from: group.id), "admin removes C")
		check(a.group(group.id)?.members.contains("C") == false, "admin roster drops C")
		check(c.groups[group.id] == nil, "evicted C drops its own replica")
		check(b.group(group.id)?.members.contains("C") == false, "B converged: C gone")

		// --- Leave ---
		print("[leave]")
		check(b.leaveGroup(group.id), "B leaves")
		check(b.groups[group.id] == nil, "B dropped its replica")
		check(a.group(group.id)?.members.contains("B") == false, "admin roster drops B on leave")

		// --- Delete (admin) ---
		print("[admin delete]")
		check(a.inviteMember("B", to: group.id), "re-invite B")
		check(b.acceptInvite(group.id), "B rejoins")
		check(a.deleteGroup(group.id), "admin deletes group")
		check(a.groups[group.id] == nil, "admin replica gone")
		check(b.groups[group.id] == nil, "member B replica gone after delete")

		// --- Root-cause regression: invite must be addressed to the invitee's OWN localPeerID ---
		// Reproduces the real-device bug: if the inviter addresses an ID that is not the
		// invitee's localPeerID (as happened when the transport's self-ID carried a vendor
		// suffix that peers never saw), the invite is silently dropped. The transport fix
		// guarantees the addressed ID == the invitee's localPeerID; this guards the invariant.
		print("[regression: invite addressing must match invitee localPeerID]")
		let mesh2 = FakeMesh()
		let admin = mesh2.addNode("Alice")
		let bob2 = mesh2.addNode("Bob-vendor9f8e")   // bob2.localPeerID == "Bob-vendor9f8e"
		let g2 = admin.createGroup(name: "Trip")
		check(admin.inviteMember("Bob", to: g2.id), "invite sent to a mismatched ID (bare displayName)")
		check(bob2.receivedInvites[g2.id] == nil, "mismatched-ID invite is NOT stored (bug repro)")
		check(admin.inviteMember("Bob-vendor9f8e", to: g2.id), "invite sent to the correct localPeerID")
		check(bob2.receivedInvites[g2.id] != nil, "correctly-addressed invite IS stored")

		print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
		exit(failures == 0 ? 0 : 1)
	}
}
