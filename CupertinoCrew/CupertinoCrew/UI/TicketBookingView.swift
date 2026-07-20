import SwiftUI

struct TicketBookingView: View {
    let event: MockEvent
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var groups: GroupManager
    @EnvironmentObject var wallet: WalletManager
    
    @State private var isBooking = false
    @State private var showSuccess = false
    @State private var showCreateSquadSheet = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(white: 0.07).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Image with Navigation Overlay
                    ZStack(alignment: .top) {
                        Image(event.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 450)
                            .clipped()
                            .overlay(
                                LinearGradient(colors: [.clear, .clear, Color(white: 0.07)], startPoint: .top, endPoint: .bottom)
                            )
                        
                        // Custom Navigation Bar
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Button { } label: {
                                    Image(systemName: "bookmark")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.4))
                                        .clipShape(Circle())
                                }
                                
                                Button { } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.4))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 50) // approximate safe area
                    }
                    
                    // Details Panel
                    VStack(alignment: .leading, spacing: 20) {
                        // Tags
                        HStack(spacing: 12) {
                            ForEach(event.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Text(event.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text(event.date)
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.8, green: 0.7, blue: 0.4)) // Gold color matching screenshot
                        
                        // Location
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.5))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.location)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("19.8 km away")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(.vertical, 8)
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text("Gates open at 6:30 PM")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(.vertical, 8)
                        
                        Spacer(minLength: 150) // Space for floating bar
                    }
                    .padding(24)
                    .background(Color(white: 0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .offset(y: -40)
                }
            }
            .ignoresSafeArea()
            
            // Floating Checkout Bar
            VStack(spacing: 0) {
                // EMI Banner
                HStack {
                    Image(systemName: "percent")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.blue)
                        .clipShape(Circle())
                    
                    Text("EMI available on bookings over ₹4,000")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(red: 0.16, green: 0.11, blue: 0.31)) // Deep purple
                
                // Checkout Actions
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("General sale")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Text("₹1,499 ")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        + Text("onwards")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button {
                        bookTicket()
                    } label: {
                        if isBooking {
                            ProgressView().tint(.black)
                                .frame(width: 140, height: 50)
                                .background(Color.white)
                                .clipShape(Capsule())
                        } else {
                            Text("Book tickets")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(width: 140, height: 50)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                    }
                    .disabled(isBooking)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(white: 0.12))
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            
            // Success Overlay
            if showSuccess {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    
                    SuccessSheet(event: event) {
                        showSuccess = false
                        createGroupAndInvite()
                    }
                }
                .zIndex(100)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showCreateSquadSheet) {
            let shortTitle = event.title.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? event.title
            CreateSquadView(squadName: "\(shortTitle) Squad", initialBgImage: event.imageName)
        }
    }
    
    private func bookTicket() {
        isBooking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isBooking = false
            wallet.bookTicket(for: event)
            showSuccess = true
        }
    }
    
    private func createGroupAndInvite() {
        showCreateSquadSheet = true
    }
}

struct SuccessSheet: View {
    let event: MockEvent
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.3), radius: 10)
            
            Text("You're going to \(event.title)!")
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            
            Text("Create a squad and invite your friends so you can find each other even without cellular coverage.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal)
            
            Button("Form My Squad") {
                onContinue()
            }
            .font(.subheadline)
            .fontWeight(.bold)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.white)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.top, 10)
        }
        .padding(32)
        .background(Color(white: 0.16)) // Dark gray card background
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(32)
    }
}
