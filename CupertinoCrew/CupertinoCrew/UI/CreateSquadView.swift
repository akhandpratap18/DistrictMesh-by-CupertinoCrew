import SwiftUI

struct CreateSquadView: View {
    @EnvironmentObject var bus: MessageBus
    @EnvironmentObject var groups: GroupManager
    @Environment(\.dismiss) var dismiss
    
    @State var squadName: String
    var initialBgImage: String? = nil
    
    @State private var selectedEventID: UUID?
    @State private var selectedPeers: Set<String> = []
    
    private let availableEvents = [
        MockEvent(title: "Papon Live In Concert | Delhi", imageName: "_ (3)", date: "Sun, 16 Aug, 7:00 PM", location: "Yashobhoomi, Delhi", tags: ["Concerts", "Music"], isVertical: true),
        MockEvent(title: "Tech Fest", imageName: "Earnings Presentation Q125 (dlocal)", date: "Sat, 22 Aug, 5:00 PM", location: "JLN Stadium", tags: ["Festivals", "Technology"], isVertical: true),
        MockEvent(title: "NAM A Comedy Show", imageName: "Mindmorph", date: "Fri, 28 Aug, 8:00 PM", location: "Comedy Club", tags: ["Comedy"], isVertical: true)
    ]
    
    private var currentBgImage: String? {
        if let initialBgImage = initialBgImage { return initialBgImage }
        return availableEvents.first(where: { $0.id == selectedEventID })?.imageName
    }
    
    var body: some View {
        ZStack {
            Color(white: 0.07).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                if let bgImage = currentBgImage {
                    ZStack(alignment: .top) {
                        Image(bgImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 250)
                            .clipped()
                            .overlay(
                                LinearGradient(colors: [.clear, Color(white: 0.07)], startPoint: .top, endPoint: .bottom)
                            )
                        
                        ZStack {
                            Text("New Squad")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            HStack {
                                Spacer()
                                Button { dismiss() } label: {
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
                        .padding(.top, 50)
                    }
                } else {
                    ZStack {
                        Text("New Squad")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        HStack {
                            Spacer()
                            Button { dismiss() } label: {
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
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Event Selector (only show if no initial event was provided)
                        if initialBgImage == nil {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Select Event")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                Menu {
                                    ForEach(availableEvents) { event in
                                        Button(event.title) {
                                            selectedEventID = event.id
                                            let shortTitle = event.title.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? event.title
                                            squadName = "\(shortTitle) Squad"
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(availableEvents.first(where: { $0.id == selectedEventID })?.title ?? "Choose an event...")
                                            .foregroundStyle(selectedEventID == nil ? .white.opacity(0.5) : .white)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    .padding()
                                    .background(Color(white: 0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                        
                        // Squad Info Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Squad Details")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Name")
                                        .foregroundStyle(.white.opacity(0.7))
                                    Spacer()
                                    TextField("Squad Name", text: $squadName)
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                            .padding()
                            .background(Color(white: 0.12)) // Dark gray panel
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        
                        // Add Members Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Add Members")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            let invitablePeers = bus.connectedPeerIDs
                            
                            VStack(spacing: 0) {
                                if invitablePeers.isEmpty {
                                    Text("No nearby friends found on mesh network")
                                        .foregroundStyle(.white.opacity(0.5))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                } else {
                                    ForEach(invitablePeers, id: \.self) { peer in
                                        let isSelected = selectedPeers.contains(peer)
                                        HStack {
                                            Text(peer.shortPeerName)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                            
                                            Spacer()
                                            
                                            Button {
                                                if isSelected {
                                                    selectedPeers.remove(peer)
                                                } else {
                                                    selectedPeers.insert(peer)
                                                }
                                            } label: {
                                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                                    .font(.system(size: 24))
                                                    .foregroundStyle(isSelected ? Color(red: 1.0, green: 0.1, blue: 0.6) : .white.opacity(0.3))
                                            }
                                        }
                                        .padding()
                                        
                                        if peer != invitablePeers.last {
                                            Divider().background(Color.white.opacity(0.1))
                                                .padding(.leading)
                                        }
                                    }
                                }
                            }
                            .background(Color(white: 0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        
                        Spacer(minLength: 40)
                        
                        Button {
                            let name = squadName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !name.isEmpty {
                                let group = groups.createGroup(name: name)
                                for peer in selectedPeers {
                                    groups.inviteMember(peer, to: group.id)
                                }
                                dismiss()
                            }
                        } label: {
                            Text("Create Squad")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(squadName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(squadName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    }
                    .padding()
                }
            }
        }
    }
}
