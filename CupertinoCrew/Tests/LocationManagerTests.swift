// Standalone LocationManager harness. Real LocationManager against a fake channel + fake
// provider — no MultipeerConnectivity, no CoreLocation, no XCTest.
//   swiftc -parse-as-library \
//     CupertinoCrew/CupertinoCrew/Mesh/MeshMessage.swift \
//     CupertinoCrew/CupertinoCrew/Mesh/MeshGroup.swift \
//     CupertinoCrew/CupertinoCrew/Mesh/GroupManager.swift \
//     CupertinoCrew/CupertinoCrew/Location/GeoMath.swift \
//     CupertinoCrew/CupertinoCrew/Location/LocationBeaconPayload.swift \
//     CupertinoCrew/CupertinoCrew/Location/DeviceLocationProvider.swift \
//     CupertinoCrew/CupertinoCrew/Location/LocationManager.swift \
//     CupertinoCrew/Tests/LocationManagerTests.swift -o /tmp/loctests && /tmp/loctests

import Foundation
import Combine

private var failures = 0
private func check(_ cond: Bool, _ label: String) {
	if cond { print("  ok   \(label)") } else { failures += 1; print("  FAIL \(label)") }
}

@MainActor
final class FakeChannel: GroupPacketChannel {
	let localPeerID: String
	let inboundSubject = PassthroughSubject<MeshPacket, Never>()
	var groupInbox: AnyPublisher<MeshPacket, Never> { inboundSubject.eraseToAnyPublisher() }
	var sent: [MeshPacket] = []
	init(_ id: String) { localPeerID = id }
	func send(_ packet: MeshPacket) { sent.append(packet) }
}

@MainActor
final class FakeProvider: DeviceLocationProvider {
	var currentCoordinate: GeoCoordinate?
	var currentHeadingDegrees: Double?
	private let subject = PassthroughSubject<Void, Never>()
	var didUpdate: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }
	var started = false
	func start() { started = true }
}

@MainActor
func beaconPacket(from peer: String, lat: Double, lon: Double) -> MeshPacket {
	let payload = LocationBeaconPayload(latitude: lat, longitude: lon, sampledAt: Date())
	let data = try! JSONEncoder().encode(payload)
	return MeshPacket(type: .locationBeacon, priority: .normal, originPeerID: peer,
		validFor: 30, payload: data)
}

@main
struct Runner {
	@MainActor
	static func main() {
		// --- Ingest: inbound beacon populates peerFixes keyed by originPeerID ---
		let ch = FakeChannel("Me")
		let provider = FakeProvider()
		let mgr = LocationManager(channel: ch, provider: provider)
		ch.inboundSubject.send(beaconPacket(from: "Bob", lat: 0, lon: 1))
		check(mgr.peerFixes["Bob"]?.coordinate == GeoCoordinate(latitude: 0, longitude: 1), "Bob fix ingested")

		// --- Own echo ignored ---
		ch.inboundSubject.send(beaconPacket(from: "Me", lat: 5, lon: 5))
		check(mgr.peerFixes["Me"] == nil, "own beacon echo ignored")

		// --- track(): bearing/distance from our fix to Bob ---
		provider.currentCoordinate = GeoCoordinate(latitude: 0, longitude: 0)
		provider.currentHeadingDegrees = 90
		let track = mgr.track("Bob")
		check(track != nil, "track returns a value when both fixes present")
		check(abs((track?.bearingDegrees ?? -1) - 90) < 0.5, "bearing to due-east Bob is ~90")
		check(abs((track?.distanceMeters ?? -1) - 111_319) < 1000, "distance to Bob ~111km")
		check(track?.isStale == false, "fresh fix not stale")
		// Arrow: bearing 90 - heading 90 = 0 (straight ahead).
		check(abs((track?.arrowRotationDegrees ?? -1)) < 0.5, "arrow points straight ahead when facing target")

		// --- Staleness after TTL ---
		let staleTrack = mgr.track("Bob", now: Date().addingTimeInterval(31))
		check(staleTrack?.isStale == true, "fix older than TTL is stale")

		// --- track() nil when own fix missing ---
		let ch2 = FakeChannel("Me2")
		let prov2 = FakeProvider()   // no coordinate
		let mgr2 = LocationManager(channel: ch2, provider: prov2)
		ch2.inboundSubject.send(beaconPacket(from: "Cara", lat: 1, lon: 1))
		check(mgr2.track("Cara") == nil, "track nil when own coordinate missing")

		// --- broadcastCurrentFix: sends one .locationBeacon when we have a fix ---
		provider.currentCoordinate = GeoCoordinate(latitude: 12, longitude: 34)
		ch.sent.removeAll()
		mgr.broadcastCurrentFix()
		check(ch.sent.count == 1, "one packet sent on broadcast")
		check(ch.sent.first?.type == .locationBeacon, "sent packet is a locationBeacon")
		if let data = ch.sent.first?.payload,
		   let decoded = try? JSONDecoder().decode(LocationBeaconPayload.self, from: data) {
			check(decoded.latitude == 12 && decoded.longitude == 34, "broadcast payload carries our coordinate")
		} else {
			check(false, "broadcast payload decodes")
		}

		// --- broadcastCurrentFix: no-op with no fix ---
		let ch3 = FakeChannel("Me3")
		let prov3 = FakeProvider()
		let mgr3 = LocationManager(channel: ch3, provider: prov3)
		mgr3.broadcastCurrentFix()
		check(ch3.sent.isEmpty, "no packet sent before first GPS fix")

		print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
		exit(failures == 0 ? 0 : 1)
	}
}
