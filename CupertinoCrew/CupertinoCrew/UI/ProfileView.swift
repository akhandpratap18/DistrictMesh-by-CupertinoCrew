import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var wallet: WalletManager
    @EnvironmentObject var groups: GroupManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.07).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // User Profile Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.15))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color(red: 1.0, green: 0.1, blue: 0.6))
                            }
                            
                            Text(groups.localPeerID)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 20)
                        
                        // Offline Wallet Card
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Image(systemName: "wifi.slash")
                                    .foregroundStyle(Color(red: 1.0, green: 0.1, blue: 0.6))
                                Text("Offline Wallet")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "creditcard.fill")
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Available Balance")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                                Text("₹\(wallet.balance)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            
                            HStack {
                                Button {} label: {
                                    Text("Add Funds")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.1))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                
                                Button {} label: {
                                    Text("Withdraw")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.1))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(24)
                        .background(Color(white: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.05), lineWidth: 1))
                        .padding(.horizontal, 20)
                        
                        // Transaction History
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Transactions")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                            
                            if wallet.transactions.isEmpty {
                                Text("No transactions yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .padding(.horizontal, 24)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(wallet.transactions) { tx in
                                        HStack(spacing: 16) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(white: 0.15))
                                                    .frame(width: 48, height: 48)
                                                Image(systemName: "cart.fill")
                                                    .foregroundStyle(.white.opacity(0.7))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(tx.itemName)
                                                    .font(.headline)
                                                    .foregroundStyle(.white)
                                                Text(tx.vendorName)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.white.opacity(0.5))
                                            }
                                            
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text("-₹\(tx.amount)")
                                                    .font(.headline)
                                                    .foregroundStyle(.white)
                                                
                                                HStack(spacing: 4) {
                                                    Circle()
                                                        .fill(Color.green)
                                                        .frame(width: 6, height: 6)
                                                    Text(tx.status.rawValue.capitalized)
                                                        .font(.caption)
                                                        .foregroundStyle(Color.green)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        
                                        if tx.id != wallet.transactions.last?.id {
                                            Divider().background(Color.white.opacity(0.1))
                                                .padding(.leading, 88)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(white: 0.07), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
