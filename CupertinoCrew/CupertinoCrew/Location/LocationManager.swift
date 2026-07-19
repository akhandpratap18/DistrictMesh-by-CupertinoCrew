import Foundation
import Combine

/// One peer's most recent reported location and when this device received it.
struct PeerFix: Equatable {
	let coordinate: GeoCoordinate
	let receivedAt: Date
}

/// Computed guidance from this device toward a tracked peer.
struct FriendTrack: Equatable {
	let bearingDegrees: Double        // target direction, clockwise from true north
	let distanceMeters: Double
	let deviceHeadingDegrees: Double? // nil when no magnetometer/heading
	let isStale: Bool                 // target fix older than the beacon TTL

	/// How far to rotate a north-pointing arrow for a heading-up display. With a heading it
	/// points the real-world way to turn; without one it falls back to the absolute bearing.
	var arrowRotationDegrees: Double {
		guard let heading = deviceHeadingDegrees else { return bearingDegrees }
		return (bearingDegrees - heading + 360).truncatingRemainder(dividingBy: 360)
	}
}

/// Floods this device's GPS coordinate over the mesh (always-on while the app runs), ingests
/// peers' beacons, and computes direction/distance to one chosen peer. Mirrors the
/// `GroupManager` pattern: consumes `GroupPacketChannel`, never relays, only reads inbound
/// packets and originates its own.
@MainActor
final class LocationManager: ObservableObject {
	/// Latest fix per peer, keyed by `originPeerID`. Published so a tracker view refreshes live.
	@Published private(set) var peerFixes: [String: PeerFix] = [:]

	/// Beacon lifetime on the mesh and the staleness threshold for a tracked peer.
	static let beaconTTL: TimeInterval = 30
	/// How often this device floods its own coordinate while the app runs.
	static let broadcastInterval: TimeInterval = 4

	private let channel: GroupPacketChannel
	private let provider: DeviceLocationProvider
	private var cancellables = Set<AnyCancellable>()
	private var broadcastTimer: Timer?

	var localPeerID: String { channel.localPeerID }

	init(channel: GroupPacketChannel, provider: DeviceLocationProvider) {
		self.channel = channel
		self.provider = provider
		channel.groupInbox
			.sink { [weak self] packet in self?.handleInbound(packet) }
			.store(in: &cancellables)
	}

	deinit { broadcastTimer?.invalidate() }

	/// Start GPS/heading and begin flooding our own coordinate on a timer (always-on).
	func start() {
		provider.start()
		broadcastTimer?.invalidate()
		broadcastTimer = Timer.scheduledTimer(withTimeInterval: Self.broadcastInterval, repeats: true) { [weak self] _ in
			Task { @MainActor in self?.broadcastCurrentFix() }
		}
	}

	/// Encode the current GPS fix as a beacon and flood it. No-op until the first fix.
	func broadcastCurrentFix() {
		guard let coord = provider.currentCoordinate else { return }
		let payload = LocationBeaconPayload(latitude: coord.latitude, longitude: coord.longitude, sampledAt: Date())
		guard let data = try? JSONEncoder().encode(payload) else { return }
		let packet = MeshPacket(
			type: .locationBeacon, priority: .normal, originPeerID: localPeerID,
			validFor: Self.beaconTTL, payload: data)
		channel.send(packet)
	}

	/// Direction + distance from this device to `peerID`, or nil if either fix is missing.
	func track(_ peerID: String, now: Date = Date()) -> FriendTrack? {
		guard let mine = provider.currentCoordinate, let fix = peerFixes[peerID] else { return nil }
		return FriendTrack(
			bearingDegrees: GeoMath.initialBearingDegrees(from: mine, to: fix.coordinate),
			distanceMeters: GeoMath.distanceMeters(from: mine, to: fix.coordinate),
			deviceHeadingDegrees: provider.currentHeadingDegrees,
			isStale: now.timeIntervalSince(fix.receivedAt) > Self.beaconTTL)
	}

	private func handleInbound(_ packet: MeshPacket) {
		guard packet.type == .locationBeacon else { return }
		guard packet.originPeerID != localPeerID else { return }   // ignore our own echo
		guard let payload = try? JSONDecoder().decode(LocationBeaconPayload.self, from: packet.payload) else { return }
		peerFixes[packet.originPeerID] = PeerFix(coordinate: payload.coordinate, receivedAt: Date())
	}
}
