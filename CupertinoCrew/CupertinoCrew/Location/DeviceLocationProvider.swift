import Foundation
import Combine

/// Abstracts the device's GPS + compass so `LocationManager` is unit-testable with a
/// scripted fake, and the concrete CoreLocation implementation lives in its own file.
@MainActor
protocol DeviceLocationProvider: AnyObject {
	/// Latest known device coordinate, or nil before the first GPS fix.
	var currentCoordinate: GeoCoordinate? { get }
	/// Latest true heading in degrees (0..<360, clockwise from true north), or nil if unavailable.
	var currentHeadingDegrees: Double? { get }
	/// Fires whenever the coordinate or heading changes.
	var didUpdate: AnyPublisher<Void, Never> { get }
	/// Begin GPS + heading updates (requests authorization as needed).
	func start()
}
