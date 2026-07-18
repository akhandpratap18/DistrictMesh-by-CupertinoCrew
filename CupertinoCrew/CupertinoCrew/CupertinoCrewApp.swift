//
//  CupertinoCrewApp.swift
//  CupertinoCrew
//
//  Created by Paarth Singh  on 18/07/26.
//

import SwiftUI

@main
struct CupertinoCrewApp: App {
    @StateObject private var bus = MessageBus(transport: MultipeerTransport())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bus)
                .safeAreaInset(edge: .top) {
                    MeshStatusView(bus: bus)
                }
                .onAppear { bus.start() }
        }
    }
}
