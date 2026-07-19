//
//  CupertinoCrewApp.swift
//  CupertinoCrew
//
//  Created by Paarth Singh  on 18/07/26.
//

import SwiftUI

@main
struct CupertinoCrewApp: App {
    @AppStorage("userName") private var userName: String = ""

    var body: some Scene {
        WindowGroup {
            if userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                OnboardingView(userName: $userName)
            } else {
                MainAppView(userName: userName)
            }
        }
    }
}

struct MainAppView: View {
    @StateObject private var bus: MessageBus
    @StateObject private var groups: GroupManager
    @StateObject private var location: LocationManager
    @StateObject private var wallet = WalletManager()

    init(userName: String) {
        let bus = MessageBus(transport: MultipeerTransport(displayName: userName))
        _bus = StateObject(wrappedValue: bus)
        _groups = StateObject(wrappedValue: GroupManager(channel: bus))
        _location = StateObject(wrappedValue: LocationManager(channel: bus, provider: CoreLocationProvider()))
    }

    var body: some View {
        ContentView()
            .environmentObject(bus)
            .environmentObject(groups)
            .environmentObject(location)
            .environmentObject(wallet)
            .onAppear {
                bus.start()
                location.start()
            }
    }
}

struct OnboardingView: View {
    @Binding var userName: String
    @State private var inputName: String = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 80))
                        .foregroundStyle(Color(red: 0.2, green: 0.9, blue: 0.6))
                    
                    Text("Welcome to District")
                        .font(.title)
                        .fontWeight(.heavy)
                        .foregroundStyle(.white)
                    
                    Text("What should your friends call you on the mesh network?")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 32)
                }
                
                TextField("Your Name", text: $inputName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(white: 0.15))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 40)
                
                Button {
                    let trimmed = inputName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        userName = trimmed
                    }
                } label: {
                    Text("Join the Party")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [Color(red: 0.2, green: 0.9, blue: 0.6), Color(red: 0.1, green: 0.7, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color(red: 0.2, green: 0.9, blue: 0.6).opacity(0.4), radius: 8)
                }
                .padding(.horizontal, 40)
                .disabled(inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                
                Spacer()
            }
        }
    }
}
