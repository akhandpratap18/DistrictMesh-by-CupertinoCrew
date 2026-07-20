import SwiftUI

struct MockEvent: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let imageName: String
    let date: String
    let location: String
    let tags: [String]
    let isVertical: Bool
}

struct EventCategory: Identifiable {
    let id = UUID()
    let name: String
    let image: String
}

struct EventDiscoveryView: View {
    let events = [
        MockEvent(title: "Papon Live In Concert | Delhi", imageName: "_ (3)", date: "Sun, 16 Aug, 7:00 PM", location: "Yashobhoomi, Delhi", tags: ["Concerts", "Music"], isVertical: true),
        MockEvent(title: "Tech Fest", imageName: "Earnings Presentation Q125 (dlocal)", date: "Sat, 22 Aug, 5:00 PM", location: "JLN Stadium", tags: ["Festivals", "Technology"], isVertical: true),
        MockEvent(title: "NAM A Comedy Show", imageName: "Mindmorph", date: "Fri, 28 Aug, 8:00 PM", location: "Comedy Club", tags: ["Comedy"], isVertical: true)
    ]
    
    let categories = [
        EventCategory(name: "Comedy", image: "mic.fill"),
        EventCategory(name: "Music", image: "guitars.fill"),
        EventCategory(name: "Screenings", image: "film.fill"),
        EventCategory(name: "Food & Drinks", image: "fork.knife")
    ]
    
    @State private var searchText = ""
    @State private var showProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.07).ignoresSafeArea() // Deep dark gray background
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Events")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                HStack(spacing: 4) {
                                    Text("Chhatarpur Farms")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.7))
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Button { } label: {
                                    Image(systemName: "bookmark")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                
                                Button { showProfile = true } label: {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .frame(width: 44, height: 44)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Search Bar
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.5))
                            TextField("Search for 'Jonas Brothers'", text: $searchText)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal)
                        
                        // What's happening this week
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(spacing: 4) {
                                Text("What's happening")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                
                                Text("this week")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .overlay(
                                        Rectangle()
                                            .fill(Color.white.opacity(0.5))
                                            .frame(height: 1)
                                            .offset(y: 4)
                                        , alignment: .bottom
                                    )
                                
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(.leading, 4)
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 24) {
                                    ForEach(categories) { category in
                                        VStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white.opacity(0.1))
                                                    .frame(width: 80, height: 80)
                                                
                                                Image(systemName: category.image)
                                                    .font(.system(size: 30))
                                                    .foregroundStyle(.white)
                                            }
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(
                                                        LinearGradient(colors: [Color(red: 1.0, green: 0.1, blue: 0.6), Color(red: 0.7, green: 0.1, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                                        lineWidth: 3
                                                    )
                                            )
                                            
                                            Text(category.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.white)
                                                .multilineTextAlignment(.center)
                                                .frame(width: 80)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Continue where you left off
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Continue where you left off")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(events) { event in
                                        NavigationLink {
                                            TicketBookingView(event: event)
                                        } label: {
                                            EventCard(event: event)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
    }
}

struct EventCard: View {
    let event: MockEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(event.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 240, height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                Button { } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(12)
            }
            
            Text(event.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: 240, alignment: .leading)
        }
    }
}
