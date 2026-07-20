import SwiftUI

struct GroupChatListView: View {
    @EnvironmentObject var bus: MessageBus
    @EnvironmentObject var groups: GroupManager
    
    @State private var showCreateSquadSheet = false
    @State private var navigateToGroupID: UUID?
    
    private var myGroups: [MeshGroup] { groups.myGroups.sorted { $0.name < $1.name } }
    private var myInvites: [GroupInvite] { Array(groups.receivedInvites.values).sorted { $0.groupName < $1.groupName } }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(white: 0.07).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    HStack {
                        Text("My Squads")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Button {
                            showCreateSquadSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    if myGroups.isEmpty && myInvites.isEmpty {
                        Spacer()
                        ContentUnavailableView {
                            Label("No Squads Yet", systemImage: "person.3.slash")
                                .foregroundStyle(.white)
                        } description: {
                            Text("Book an event ticket to create a squad, or check back for invites.")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                // Pending Invites
                                ForEach(myInvites) { invite in
                                    Button {
                                        groups.acceptInvite(invite.groupID)
                                        DispatchQueue.main.async {
                                            navigateToGroupID = invite.groupID
                                        }
                                    } label: {
                                        InviteCard(invite: invite)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Joined Squads
                                ForEach(myGroups) { group in
                                    NavigationLink {
                                        ChatRoomView(group: group)
                                    } label: {
                                        SquadCard(group: group)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showCreateSquadSheet) {
                CreateSquadView(squadName: "My Squad")
            }
            .navigationDestination(isPresented: Binding(
                get: { navigateToGroupID != nil },
                set: { if !$0 { navigateToGroupID = nil } }
            )) {
                if let id = navigateToGroupID, let group = groups.group(id) {
                    ChatRoomView(group: group)
                }
            }
        }
    }
}

struct InviteCard: View {
    let invite: GroupInvite
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .strokeBorder(Color(red: 1.0, green: 0.1, blue: 0.6), lineWidth: 2)
                    .frame(width: 56, height: 56)
                
                Image(systemName: "envelope.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 1.0, green: 0.1, blue: 0.6))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(invite.groupName)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("Invited by \(invite.invitedBy.shortPeerName)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            Text("Accept")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(red: 1.0, green: 0.1, blue: 0.6))
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .padding()
        .background(Color(white: 0.12)) // Dark gray panel
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct SquadCard: View {
    let group: MeshGroup
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.1, blue: 0.6)) // Pink accent
                    .frame(width: 56, height: 56)
                    .shadow(color: Color(red: 1.0, green: 0.1, blue: 0.6).opacity(0.4), radius: 8)
                
                Text(String(group.name.prefix(1)))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("\(group.members.count) members")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding()
        .background(Color(white: 0.12)) // Dark gray panel
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
