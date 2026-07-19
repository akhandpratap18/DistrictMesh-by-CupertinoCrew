import SwiftUI

/// Full-screen heading-relative direction arrow toward one tracked group member, plus an
/// approximate distance. No map, no route — direction only. Refreshes on a timer so the arrow
/// tracks both incoming beacons and the device turning.
struct FriendTrackerView: View {
	@EnvironmentObject private var location: LocationManager

	let peerID: String
	let displayName: String

	// Drives periodic recompute (device heading + fix freshness) independent of @Published changes.
	@State private var tick = Date()
	private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

	private var track: FriendTrack? { location.track(peerID, now: tick) }

	var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()
			VStack(spacing: 40) {
				Text(displayName)
					.font(.title).fontWeight(.heavy)
					.foregroundStyle(.white)

				content
			}
			.padding()
		}
		.preferredColorScheme(.dark)
		.onReceive(timer) { tick = $0 }
	}

	@ViewBuilder
	private var content: some View {
		if let track {
			let dimmed = track.isStale
			Image(systemName: "location.north.fill")
				.font(.system(size: 140))
				.foregroundStyle(Color(red: 0.2, green: 0.9, blue: 0.6))
				.rotationEffect(.degrees(track.arrowRotationDegrees))
				.opacity(dimmed ? 0.35 : 1)
				.animation(.easeInOut(duration: 0.3), value: track.arrowRotationDegrees)

			Text(GeoMath.approxDistanceLabel(track.distanceMeters))
				.font(.system(size: 44, weight: .bold, design: .rounded))
				.foregroundStyle(.white)

			if track.deviceHeadingDegrees == nil {
				Text("Compass unavailable — showing map bearing")
					.font(.footnote).foregroundStyle(.white.opacity(0.6))
			}
			if dimmed {
				Text("Waiting for \(displayName)'s signal…")
					.font(.footnote).foregroundStyle(.orange.opacity(0.9))
			}
		} else if location.track(peerID) == nil {
			ProgressView()
				.tint(.white)
			Text("Getting locations… make sure location is enabled and \(displayName) is nearby on the mesh.")
				.multilineTextAlignment(.center)
				.font(.footnote).foregroundStyle(.white.opacity(0.6))
		}
	}
}
