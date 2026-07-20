import Foundation
import Combine

struct Transaction: Identifiable, Codable {
    let id: UUID
    let itemName: String
    let amount: Int
    let vendorName: String
    let vendorID: String
    var status: TransactionStatus
    let timestamp: Date
}

enum TransactionStatus: String, Codable {
    case pending
    case confirmed
    case failed
}

struct PaymentPayload: Codable, Equatable {
    let transactionID: String
    let amount: Int
    let itemName: String
}

class WalletManager: ObservableObject {
    @Published var balance: Int = 5000
    @Published var transactions: [Transaction] = []
    @Published var bookedEvents: [MockEvent] = []
    
    func bookTicket(for event: MockEvent) {
        if !bookedEvents.contains(where: { $0.id == event.id }) {
            bookedEvents.append(event)
        }
    }
    
    func purchase(itemName: String, amount: Int, vendorName: String, vendorID: String, bus: MessageBus) {
        guard balance >= amount else { return }
        balance -= amount
        
        // Simulating immediate confirmation for the hackathon offline wallet demo
        let tx = Transaction(id: UUID(), itemName: itemName, amount: amount, vendorName: vendorName, vendorID: vendorID, status: .confirmed, timestamp: Date())
        transactions.insert(tx, at: 0)
        
        let payload = PaymentPayload(transactionID: tx.id.uuidString, amount: amount, itemName: itemName)
        if let data = try? JSONEncoder().encode(payload) {
            let packet = MeshPacket(
                type: .payment,
                priority: .high,
                originPeerID: bus.localPeerID,
                validFor: 3600,
                payload: data,
                destinationPeerID: vendorID,
                groupID: nil
            )
            bus.send(packet)
        }
    }
}
