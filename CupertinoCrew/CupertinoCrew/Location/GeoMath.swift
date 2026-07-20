import Foundation

/// A plain latitude/longitude pair, free of CoreLocation so the pure geometry below and
/// `LocationManager` can be unit-tested with no Apple location frameworks linked.
struct GeoCoordinate: Equatable {
	let latitude: Double
	let longitude: Double
}

/// Pure great-circle geometry and display helpers. No state, no dependencies.
enum GeoMath {
	/// Haversine distance in meters between two coordinates.
	static func distanceMeters(from a: GeoCoordinate, to b: GeoCoordinate) -> Double {
		let earthRadius = 6_371_000.0
		let lat1 = a.latitude * .pi / 180
		let lat2 = b.latitude * .pi / 180
		let dLat = (b.latitude - a.latitude) * .pi / 180
		let dLon = (b.longitude - a.longitude) * .pi / 180
		let h = sin(dLat / 2) * sin(dLat / 2)
			+ cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
		return 2 * earthRadius * asin(min(1, sqrt(h)))
	}

	/// Initial great-circle bearing from `a` to `b`, degrees clockwise from true north (0..<360).
	static func initialBearingDegrees(from a: GeoCoordinate, to b: GeoCoordinate) -> Double {
		let lat1 = a.latitude * .pi / 180
		let lat2 = b.latitude * .pi / 180
		let dLon = (b.longitude - a.longitude) * .pi / 180
		let y = sin(dLon) * cos(lat2)
		let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
		let deg = atan2(y, x) * 180 / .pi
		return (deg + 360).truncatingRemainder(dividingBy: 360)
	}

	/// Whether a raw GPS sample is trustworthy enough to use and broadcast. Rejects three
	/// bad-input classes that otherwise corrupt every bearing/distance downstream:
	///   - invalid fixes (`horizontalAccuracy <= 0`, CoreLocation's "no fix" sentinel),
	///   - too-coarse fixes (accuracy worse than `maxAccuracyMeters`),
	///   - stale/cached fixes — iOS commonly delivers a cached location first, often from a
	///     previous session and kilometres away; `ageSeconds` past `maxAgeSeconds` drops it.
	/// This is the fix for "friend shows 5 km away / arrow stuck at a fixed wrong angle": a
	/// cached coordinate is a fixed wrong point, so it skews distance and bearing together.
	static func isAcceptableFix(horizontalAccuracy: Double, ageSeconds: Double,
	                            maxAccuracyMeters: Double = 100, maxAgeSeconds: Double = 10) -> Bool {
		horizontalAccuracy > 0 && horizontalAccuracy <= maxAccuracyMeters && ageSeconds <= maxAgeSeconds
	}

	/// Coarse, privacy-preserving distance label ("approx", never exact).
	static func approxDistanceLabel(_ meters: Double) -> String {
		switch meters {
		case ..<15: return "~10 m"
		case ..<75: return "~50 m"
		case ..<300: return "~200 m"
		case ..<750: return "~500 m"
		case ..<1500: return "~1 km"
		default:
			let km = (meters / 1000).rounded()
			return "~\(Int(km)) km"
		}
	}
}
