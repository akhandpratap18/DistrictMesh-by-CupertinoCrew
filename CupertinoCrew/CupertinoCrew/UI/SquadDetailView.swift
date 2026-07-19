import SwiftUI

extension String {
    var shortPeerName: String {
        return self.components(separatedBy: "#").first ?? self
    }
}

struct SquadDetailView: View {
    @EnvironmentObject var bus: MessageBus
    @EnvironmentObject var groups: GroupManager
    @EnvironmentObject var location: LocationManager
    @Environment(\.dismiss) private var dismiss
    @State private var trackedMember: String?

    let groupID: UUID
    var bgImage: String? = nil
    let onAction: (String, Bool) -> Void
    
    private var group: MeshGroup? { groups.group(groupID) }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(white: 0.07).ignoresSafeArea()
            
            if let group = group {
                content(group)
            } else {
                ContentUnavailableView("Squad not found", systemImage: "person.3.slash")
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(item: Binding(
            get: { trackedMember.map { TrackedPeer(id: $0) } },
            set: { trackedMember = $0?.id }
        )) { peer in
            NavigationStack {
                FriendTrackerView(peerID: peer.id, displayName: peer.id.shortPeerName)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { trackedMember = nil }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func content(_ group: MeshGroup) -> some View {
        let isLeader = group.isAdmin(groups.localPeerID)
        
        ScrollView {
            VStack(spacing: 0) {
                // Hero Image & Custom Navigation
                ZStack(alignment: .top) {
                    if let bgImage = bgImage {
                        Image(bgImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 250)
                            .clipped()
                            .overlay(
                                LinearGradient(colors: [.clear, Color(white: 0.07)], startPoint: .top, endPoint: .bottom)
                            )
                    } else {
                        Color(white: 0.07).frame(height: 120)
                    }
                    
                    // Custom Navigation Bar
                    ZStack {
                        Text(group.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        HStack {
                            Spacer()
                            
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 50) // safe area approx
                }
                
                VStack(spacing: 24) {
                    // Network Status Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Mesh Network")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Circle()
                                    .fill(bus.peerCount > 0 ? Color(red: 1.0, green: 0.1, blue: 0.6) : (bus.isRunning ? .orange : .white.opacity(0.3)))
                                    .frame(width: 8, height: 8)
                                Text(bus.peerCount > 0 ? "\(bus.peerCount) connected peers" : (bus.isRunning ? "Searching for peers…" : "Not searching"))
                                    .foregroundStyle(.white)
                                Spacer()
                                Label("OFFLINE / no internet", systemImage: "wifi.slash")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(Color(white: 0.12)) // Dark gray panel
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // Squad Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Squad Info")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Name")
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text(group.name)
                                    .foregroundStyle(.white)
                            }
                            
                            Divider().background(Color.white.opacity(0.2))
                            
                            HStack {
                                Text("Leader")
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text(group.adminPeerID.shortPeerName)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding()
                        .background(Color(white: 0.12)) // Dark gray panel
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // Members Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Members (\(group.members.count))")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        VStack(spacing: 12) {
                            ForEach(Array(group.members).sorted(), id: \.self) { member in
                                HStack {
                                    Text(member.shortPeerName)
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                    
                                    if isLeader && member != groups.localPeerID {
                                        Button("Remove") {
                                            onAction("Remove \(member.shortPeerName)", groups.removeMember(member, from: groupID))
                                        }
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.1))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                    }

                                    if member != groups.localPeerID {
                                        Button("Locate") {
                                            trackedMember = member
                                        }
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(red: 0.2, green: 0.9, blue: 0.6).opacity(0.25))
                                        .foregroundStyle(Color(red: 0.2, green: 0.9, blue: 0.6))
                                        .clipShape(Capsule())
                                    }
                                }

                                if member != Array(group.members).sorted().last {
                                    Divider().background(Color.white.opacity(0.2))
                                }
                            }
                        }
                        .padding()
                        .background(Color(white: 0.12)) // Dark gray panel
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // Invite Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Nearby Friends to Invite")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        let invitable = bus.connectedPeerIDs.sorted().filter { !group.contains($0) }
                        
                        VStack(spacing: 12) {
                            if invitable.isEmpty {
                                Text("No nearby friends found")
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(invitable, id: \.self) { peer in
                                    HStack {
                                        Text(peer.shortPeerName)
                                            .foregroundStyle(.white)
                                        
                                        Spacer()
                                        
                                        Button {
                                            onAction("Invite", groups.inviteMember(peer, to: groupID))
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 16, weight: .bold))
                                                .frame(width: 32, height: 32)
                                                .background(Color(red: 1.0, green: 0.1, blue: 0.6))
                                                .foregroundStyle(.white)
                                                .clipShape(Circle())
                                                .shadow(color: Color(red: 1.0, green: 0.1, blue: 0.6).opacity(0.4), radius: 4)
                                        }
                                    }
                                    
                                    if peer != invitable.last {
                                        Divider().background(Color.white.opacity(0.2))
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(white: 0.12)) // Dark gray panel
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // Actions
                    HStack(spacing: 12) {
                        Button {
                            onAction("Leave", groups.leaveGroup(groupID))
                            dismiss()
                        } label: {
                            Text("Leave Squad")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        
                        if isLeader {
                            Button {
                                onAction("Delete", groups.deleteGroup(groupID))
                                dismiss()
                            } label: {
                                Text("Delete Squad")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .foregroundStyle(Color.red.opacity(0.9)) // Destructive text color
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .background(Color(white: 0.07))
            }
        }
        .ignoresSafeArea()
    }
}

/// Wraps a peer ID so it can drive `fullScreenCover(item:)`.
private struct TrackedPeer: Identifiable {
    let id: String
}
