import SwiftUI

struct MyTicketsView: View {
    @EnvironmentObject var wallet: WalletManager
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(white: 0.07).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    HStack {
                        Text("My Tickets")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    if wallet.bookedEvents.isEmpty {
                        Spacer()
                        ContentUnavailableView {
                            Label("No Tickets Yet", systemImage: "ticket")
                                .foregroundStyle(.white)
                        } description: {
                            Text("Book an event ticket to see it here.")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(wallet.bookedEvents) { event in
                                    NavigationLink {
                                        BookedTicketDetailView(event: event)
                                    } label: {
                                        BookedTicketCard(event: event)
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
        }
    }
}

struct BookedTicketCard: View {
    let event: MockEvent
    
    var body: some View {
        HStack(spacing: 0) {
            Image(event.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100)
                .clipped()
            
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                Text(event.date)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.8, green: 0.7, blue: 0.4))
                
                Text(event.location)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                Image(systemName: "qrcode")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.white)
                
                Text("ADMIT 1")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
            .background(Color.white.opacity(0.05))
        }
        .frame(height: 120)
        .background(Color(white: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MockVendor: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let items: [VendorItem]
}

struct VendorItem: Identifiable {
    let id = UUID()
    let name: String
    let price: Int
}

let mockVendors = [
    MockVendor(name: "Main Stage Food Court", icon: "fork.knife", items: [
        VendorItem(name: "Margherita Pizza", price: 400),
        VendorItem(name: "Cold Drink", price: 100),
        VendorItem(name: "French Fries", price: 150)
    ]),
    MockVendor(name: "Official Merch Stand", icon: "tshirt", items: [
        VendorItem(name: "Concert Tee", price: 1200),
        VendorItem(name: "Glow Stick", price: 200),
        VendorItem(name: "Cap", price: 800)
    ])
]

struct BookedTicketDetailView: View {
    let event: MockEvent
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var wallet: WalletManager
    @EnvironmentObject var bus: MessageBus
    
    @State private var selectedVendor: MockVendor?
    
    var body: some View {
        ZStack {
            Color(white: 0.07).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    ZStack(alignment: .top) {
                        Image(event.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 250)
                            .clipped()
                            .overlay(
                                LinearGradient(colors: [.clear, Color(white: 0.07)], startPoint: .top, endPoint: .bottom)
                            )
                        
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 50)
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        // Ticket QR Mock
                        VStack {
                            Image(systemName: "qrcode")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 150, height: 150)
                                .padding()
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            Text("Admit One")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        
                        Text("Event Vendors (Offline Ordering)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.top, 10)
                        
                        ForEach(mockVendors) { vendor in
                            Button {
                                selectedVendor = vendor
                            } label: {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color(white: 0.15))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: vendor.icon)
                                            .foregroundStyle(Color(red: 1.0, green: 0.1, blue: 0.6))
                                    }
                                    
                                    Text(vendor.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                .padding()
                                .background(Color(white: 0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedVendor) { vendor in
            VendorMenuView(vendor: vendor)
        }
    }
}

struct VendorMenuView: View {
    let vendor: MockVendor
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var wallet: WalletManager
    @EnvironmentObject var bus: MessageBus
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.07).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(vendor.items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("₹\(item.price)")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                                
                                Button {
                                    wallet.purchase(itemName: item.name, amount: item.price, vendorName: vendor.name, vendorID: "mock_vendor_\(vendor.id.uuidString)", bus: bus)
                                    dismiss()
                                } label: {
                                    Text("Pay")
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(Color(red: 1.0, green: 0.1, blue: 0.6))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding()
                            .background(Color(white: 0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(vendor.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(white: 0.07), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
