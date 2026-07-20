import SwiftUI

/// Developer-only testing surface for the Phase 6 GroupManager. Pure UI: it reads
/// published state and calls existing `GroupManager` / `MessageBus` APIs — no business
/// logic lives here. Reachable from the diagnostics screen; the rest of the app is
/// untouched. Not a shipping/user-facing screen.
struct GroupTestingView: View {
	@EnvironmentObject var bus: MessageBus
	@EnvironmentObject var groups: GroupManager

	@State private var newGroupName = ""
	/// Last operation outcome, shown so a tester can see whether a guarded op was rejected.
	@State private var lastResult: String?

	private var connectedPeers: [String] { bus.connectedPeerIDs.sorted() }
	private var myGroups: [MeshGroup] { groups.myGroups.sorted { $0.name < $1.name } }
	private var invites: [GroupInvite] { Array(groups.receivedInvites.values).sorted { $0.groupName < $1.groupName } }

	var body: some View {
		List {
			identitySection
			if let lastResult {
				Section("Last action") { Text(lastResult).font(.caption).foregroundStyle(.secondary) }
			}
			pendingInvitesSection
			createGroupSection
			groupsSection
		}
		.navigationTitle("Group Testing")
	}

	// MARK: - Identity + connectivity

	private var identitySection: some View {
		Section("Mesh") {
			LabeledContent("Local Peer ID") { Text(groups.localPeerID).font(.caption).textSelection(.enabled) }
			LabeledContent("Connected peers", value: "\(bus.peerCount)")
			if connectedPeers.isEmpty {
				Text("No connected peers").font(.caption).foregroundStyle(.secondary)
			} else {
				ForEach(connectedPeers, id: \.self) { peer in
					Text(peer).font(.caption)
				}
			}
		}
	}

	// MARK: - Pending invitations

	private var pendingInvitesSection: some View {
		Section("Pending Invitations") {
			if invites.isEmpty {
				Text("None").font(.caption).foregroundStyle(.secondary)
			}
			ForEach(invites) { invite in
				VStack(alignment: .leading, spacing: 6) {
					Text(invite.groupName).font(.subheadline).bold()
					Text("from: \(invite.invitedBy)").font(.caption2).foregroundStyle(.secondary)
					HStack {
						Button("Accept") { run("Accept \(invite.groupName)", groups.acceptInvite(invite.groupID)) }
							.buttonStyle(.borderedProminent).controlSize(.small)
						Button("Decline") { run("Decline \(invite.groupName)", groups.declineInvite(invite.groupID)) }
							.buttonStyle(.bordered).controlSize(.small).tint(.red)
					}
				}
				.padding(.vertical, 2)
			}
		}
	}

	// MARK: - Create

	private var createGroupSection: some View {
		Section("Create Group") {
			HStack {
				TextField("Group name", text: $newGroupName)
					.textInputAutocapitalization(.words)
				Button("Create") {
					let name = newGroupName.trimmingCharacters(in: .whitespaces)
					guard !name.isEmpty else { return }
					let group = groups.createGroup(name: name)
					lastResult = "Created \"\(group.name)\" (admin: you)"
					newGroupName = ""
				}
				.disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
			}
		}
	}

	// MARK: - Groups + members

	private var groupsSection: some View {
		Section("My Groups") {
			if myGroups.isEmpty {
				Text("No groups yet").font(.caption).foregroundStyle(.secondary)
			}
			ForEach(myGroups) { group in
				NavigationLink {
					GroupDetailView(groupID: group.id, run: run)
						.environmentObject(bus)
						.environmentObject(groups)
				} label: {
					HStack {
						VStack(alignment: .leading) {
							Text(group.name).font(.subheadline).bold()
							Text("\(group.members.count) member\(group.members.count == 1 ? "" : "s")")
								.font(.caption2).foregroundStyle(.secondary)
						}
						Spacer()
						if group.isAdmin(groups.localPeerID) {
							Text("ADMIN").font(.caption2).bold()
								.padding(.horizontal, 6).padding(.vertical, 2)
								.background(Color.blue.opacity(0.15), in: Capsule())
								.foregroundStyle(.blue)
						}
					}
				}
			}
		}
	}

	/// Record the boolean result of a guarded GroupManager op for on-screen feedback.
	private func run(_ label: String, _ ok: Bool) {
		lastResult = "\(label): \(ok ? "ok" : "rejected")"
	}
}

/// Member roster + admin actions for one group. Looks the group up live so it reflects
/// membership changes (and disappears if the group is deleted / this device is removed).
struct GroupDetailView: View {
	@EnvironmentObject var bus: MessageBus
	@EnvironmentObject var groups: GroupManager
	@Environment(\.dismiss) private var dismiss

	let groupID: UUID
	let run: (String, Bool) -> Void

	private var group: MeshGroup? { groups.group(groupID) }

	var body: some View {
		Group {
			if let group {
				content(group)
			} else {
				ContentUnavailableView("Group no longer available", systemImage: "person.3.slash")
			}
		}
		.navigationTitle(group?.name ?? "Group")
		.navigationBarTitleDisplayMode(.inline)
	}

	@ViewBuilder
	private func content(_ group: MeshGroup) -> some View {
		let isAdmin = group.isAdmin(groups.localPeerID)
		List {
			Section("Group") {
				LabeledContent("Name", value: group.name)
				LabeledContent("Admin") { Text(group.adminPeerID).font(.caption).textSelection(.enabled) }
				LabeledContent("You are admin", value: isAdmin ? "yes" : "no")
			}

			Section("Members (\(group.members.count))") {
				ForEach(Array(group.members).sorted(), id: \.self) { member in
					HStack {
						Text(member).font(.caption)
						if member == group.adminPeerID {
							Text("admin").font(.caption2).foregroundStyle(.blue)
						}
						Spacer()
						if isAdmin && member != groups.localPeerID {
							Button("Remove") { run("Remove \(member)", groups.removeMember(member, from: groupID)) }
								.buttonStyle(.bordered).controlSize(.small).tint(.red)
						}
					}
				}
			}

			Section("Invite Connected Peer") {
				let invitable = bus.connectedPeerIDs.sorted().filter { !group.contains($0) }
				if invitable.isEmpty {
					Text("No connected non-member peers").font(.caption).foregroundStyle(.secondary)
				}
				ForEach(invitable, id: \.self) { peer in
					HStack {
						Text(peer).font(.caption)
						Spacer()
						Button("Invite") { run("Invite \(peer)", groups.inviteMember(peer, to: groupID)) }
							.buttonStyle(.borderedProminent).controlSize(.small)
					}
				}
			}

			Section {
				Button("Leave Group", role: .destructive) {
					run("Leave", groups.leaveGroup(groupID))
					dismiss()
				}
				if isAdmin {
					Button("Delete Group (Admin)", role: .destructive) {
						run("Delete", groups.deleteGroup(groupID))
						dismiss()
					}
				}
			}
		}
	}
}
