import SwiftUI
import Combine

struct TextMessagePayload: Codable {
    let text: String
}

struct ChatBubble: Identifiable {
    let id: UUID
    let text: String
    let senderID: String
    let timestamp: Date
    let isMe: Bool
    var status: DeliveryStatus
    
    enum DeliveryStatus {
        case sending
        case queued
        case delivered
    }
}

struct ChatRoomView: View {
    let group: MeshGroup
    @EnvironmentObject var bus: MessageBus
    @EnvironmentObject var groups: GroupManager
    @Environment(\.dismiss) var dismiss
    
    @State private var messageText = ""
    @State private var messages: [ChatBubble] = []
    @State private var showSquadDetails = false
    
    var body: some View {
        ZStack {
            Color(white: 0.07).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                ZStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Button {
                            showSquadDetails = true
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    
                    VStack(spacing: 4) {
                        Text(group.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(bus.connectedPeerIDs.isEmpty ? Color.gray : Color(red: 1.0, green: 0.1, blue: 0.6))
                                .frame(width: 6, height: 6)
                            
                            Text("\(group.members.count) members • \(bus.connectedPeerIDs.count) peers nearby")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 12)
                
                Divider().background(Color.white.opacity(0.1))
                
                if messages.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.white.opacity(0.1))
                        
                        Text("No messages yet")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text("Send a message to start chatting with your squad over the mesh network.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { msg in
                                MessageView(bubble: msg)
                            }
                        }
                        .padding()
                    }
                }
                
                // Input Area
                HStack(spacing: 12) {
                    TextField("Message", text: $messageText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(white: 0.15))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                    
                    Button(action: sendMessage) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 1.0, green: 0.1, blue: 0.6)) // Pink accent
                                .frame(width: 44, height: 44)
                                .shadow(color: Color(red: 1.0, green: 0.1, blue: 0.6).opacity(0.4), radius: 6)
                            
                            Image(systemName: "arrow.up")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(white: 0.1))
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSquadDetails) {
            NavigationStack {
                SquadDetailView(groupID: group.id) { _, _ in }
            }
            .preferredColorScheme(.dark)
        }
        .onReceive(bus.inbox) { packet in
            if packet.type == .text, packet.groupID == group.id.uuidString {
                if let payload = try? JSONDecoder().decode(TextMessagePayload.self, from: packet.payload) {
                    let bubble = ChatBubble(id: packet.id, text: payload.text, senderID: packet.sourcePeerID, timestamp: packet.timestamp, isMe: false, status: .delivered)
                    messages.append(bubble)
                }
            }
        }
        .onReceive(bus.$stats) { _ in
            for i in 0..<messages.count {
                if messages[i].isMe, messages[i].status != .delivered, bus.acknowledgedPacketIDs.contains(messages[i].id) {
                    messages[i].status = .delivered
                }
            }
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messageText = ""
        
        let payload = TextMessagePayload(text: text)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        
        let packet = MeshPacket(
            type: .text,
            priority: .normal,
            originPeerID: groups.localPeerID,
            validFor: 3600, // 1 hour TTL for text messages
            payload: payloadData,
            groupID: group.id.uuidString
        )
        
        let bubble = ChatBubble(id: packet.id, text: text, senderID: groups.localPeerID, timestamp: packet.createdAt, isMe: true, status: .sending)
        messages.append(bubble)
        
        bus.send(packet)
        
        // Wait a small moment to see if any peers are online. If it's not ACK'd immediately and there's offline members, show queued.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let idx = messages.firstIndex(where: { $0.id == packet.id }) {
                if messages[idx].status == .sending {
                    // Check if anyone in the group is offline
                    let offlineMembers = group.members.filter { $0 != groups.localPeerID && !bus.connectedPeerIDs.contains($0) }
                    messages[idx].status = offlineMembers.isEmpty ? .sending : .queued
                }
            }
        }
    }
}

struct MessageView: View {
    let bubble: ChatBubble
    
    var body: some View {
        HStack {
            if bubble.isMe { Spacer() }
            
            VStack(alignment: bubble.isMe ? .trailing : .leading, spacing: 6) {
                if !bubble.isMe {
                    Text(bubble.senderID.shortPeerName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Text(bubble.text)
                    .padding(14)
                    .background(
                        bubble.isMe ? 
                        Color(red: 1.0, green: 0.1, blue: 0.6)
                        : Color(white: 0.15)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: bubble.isMe ? Color(red: 1.0, green: 0.1, blue: 0.6).opacity(0.3) : .clear, radius: 8, y: 4)
                
                if bubble.isMe {
                    HStack(spacing: 4) {
                        Text(bubble.timestamp, style: .time)
                        
                        switch bubble.status {
                        case .sending:
                            Image(systemName: "paperplane")
                        case .queued:
                            Image(systemName: "tray.and.arrow.down")
                                .foregroundStyle(.orange)
                        case .delivered:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(red: 1.0, green: 0.1, blue: 0.6))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            if !bubble.isMe { Spacer() }
        }
    }
}
