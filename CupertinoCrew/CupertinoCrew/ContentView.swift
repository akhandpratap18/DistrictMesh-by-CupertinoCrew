//
//  ContentView.swift
//  CupertinoCrew
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bus: MessageBus
    @EnvironmentObject var groups: GroupManager

    var body: some View {
        TabView {
            EventDiscoveryView()
                .tabItem {
                    Label("Discovery", systemImage: "ticket.fill")
                }
            
            MyTicketsView()
                .tabItem {
                    Label("My Tickets", systemImage: "qrcode")
                }
            
            GroupChatListView()
                .tabItem {
                    Label("My Squad", systemImage: "person.3.fill")
                }
            
            DeveloperMeshView()
                .tabItem {
                    Label("Developer", systemImage: "gearshape.fill")
                }
        }
        .tint(.white) // Neutral white accent for tabs
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(MessageBus(transport: MultipeerTransport()))
        .environmentObject(GroupManager(channel: MessageBus(transport: MultipeerTransport())))
}
