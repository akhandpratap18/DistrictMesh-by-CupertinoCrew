//
//  ContentView.swift
//  CupertinoCrew
//

import SwiftUI

/// Internal diagnostics screen for verifying the mesh transport + message bus
/// (peers, delivery, store-and-forward) before feature demos are built on top.
struct ContentView: View {
    @EnvironmentObject var bus: MessageBus

    var body: some View {
        NavigationStack {
            List {
                Section("Mesh") {
                    LabeledContent("Connected peers", value: "\(bus.peerCount)")
                    Button("Send test ping") {
                        let payload = "ping from \(UIDevice.current.name) @ \(Date().formatted(date: .omitted, time: .standard))"
                        let message = MeshMessage(
                            type: .ping,
                            priority: .normal,
                            originPeerID: UIDevice.current.name,
                            validFor: MeshMessage.pingTTL,
                            payload: Data(payload.utf8)
                        )
                        bus.send(message)
                    }
                }
                Section("Received (live, over the air)") {
                    if bus.receivedLog.isEmpty {
                        Text("Nothing received yet").foregroundStyle(.secondary)
                    }
                    ForEach(bus.receivedLog) { message in
                        let isMine = message.originPeerID == UIDevice.current.name
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(message.type.rawValue).font(.subheadline).bold()
                                if isMine {
                                    Text("sent").font(.caption2).bold()
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.blue)
                                }
                            }
                            Text(String(data: message.payload, encoding: .utf8) ?? "<binary>")
                                .font(.caption)
                            Text("hops: \(message.hopCount) · from: \(message.originPeerID)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("District Mesh")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MessageBus(transport: MultipeerTransport()))
}
