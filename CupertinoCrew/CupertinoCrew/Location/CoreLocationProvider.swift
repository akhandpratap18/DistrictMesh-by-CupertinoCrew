import Foundation
import Combine
import CoreLocation

/// Concrete `DeviceLocationProvider` backed by CoreLocation. Requests "When In Use"
/// authorization, then publishes GPS fixes and true heading. GPS is satellite-based, so this
/// works fully offline — no network is ever used.
@MainActor
final class CoreLocationProvider: NSObject, DeviceLocationProvider, CLLocationManagerDelegate {
	private(set) var currentCoordinate: GeoCoordinate?
	private(set) var currentHeadingDegrees: Double?

	private let subject = PassthroughSubject<Void, Never>()
	var didUpdate: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }

	private let manager = CLLocationManager()

	override init() {
		super.init()
		manager.delegate = self
		manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
	}

	func start() {
		manager.requestWhenInUseAuthorization()
		manager.startUpdatingLocation()
		if CLLocationManager.headingAvailable() {
			manager.startUpdatingHeading()
		}
	}

	nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let loc = locations.last else { return }
		let coord = GeoCoordinate(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
		Task { @MainActor in
			self.currentCoordinate = coord
			self.subject.send(())
		}
	}

	nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
		// Prefer true heading; it is negative when unavailable, in which case fall back to magnetic.
		let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
		Task { @MainActor in
			self.currentHeadingDegrees = heading
			self.subject.send(())
		}
	}

	nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		// Non-fatal: no fix yet. LocationManager simply keeps `currentCoordinate` nil and the
		// tracker view shows its "getting your location" state.
	}
}
