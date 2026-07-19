import Foundation

/// Wire payload for a `.locationBeacon` packet. The sender's identity is the enclosing
/// `MeshPacket.originPeerID`, so it is intentionally NOT duplicated here.
struct LocationBeaconPayload: Codable, Equatable {
	let latitude: Double
	let longitude: Double
	let sampledAt: Date

	var coordinate: GeoCoordinate {
		GeoCoordinate(latitude: latitude, longitude: longitude)
	}
}
