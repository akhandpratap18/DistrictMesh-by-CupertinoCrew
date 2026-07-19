// Standalone GeoMath correctness harness (no XCTest).
//   swiftc -parse-as-library \
//     CupertinoCrew/CupertinoCrew/Location/GeoMath.swift \
//     CupertinoCrew/Tests/GeoMathTests.swift -o /tmp/geomathtests && /tmp/geomathtests

import Foundation

private var failures = 0
private func check(_ cond: Bool, _ label: String) {
	if cond { print("  ok   \(label)") } else { failures += 1; print("  FAIL \(label)") }
}
private func approx(_ a: Double, _ b: Double, _ tol: Double, _ label: String) {
	check(abs(a - b) <= tol, "\(label) (got \(a), want ~\(b))")
}

@main
struct Runner {
	static func main() {
		let origin = GeoCoordinate(latitude: 0, longitude: 0)

		// Due north: (0,0) -> (1,0). ~111194 m, bearing 0.
		approx(GeoMath.distanceMeters(from: origin, to: GeoCoordinate(latitude: 1, longitude: 0)), 111_194, 500, "north distance")
		approx(GeoMath.initialBearingDegrees(from: origin, to: GeoCoordinate(latitude: 1, longitude: 0)), 0, 0.5, "north bearing")

		// Due east: (0,0) -> (0,1). ~111319 m, bearing 90.
		approx(GeoMath.distanceMeters(from: origin, to: GeoCoordinate(latitude: 0, longitude: 1)), 111_319, 500, "east distance")
		approx(GeoMath.initialBearingDegrees(from: origin, to: GeoCoordinate(latitude: 0, longitude: 1)), 90, 0.5, "east bearing")

		// Due west: bearing 270.
		approx(GeoMath.initialBearingDegrees(from: origin, to: GeoCoordinate(latitude: 0, longitude: -1)), 270, 0.5, "west bearing")

		// Distance label buckets.
		check(GeoMath.approxDistanceLabel(9) == "~10 m", "label 9m")
		check(GeoMath.approxDistanceLabel(60) == "~50 m", "label 60m")
		check(GeoMath.approxDistanceLabel(250) == "~200 m", "label 250m")
		check(GeoMath.approxDistanceLabel(600) == "~500 m", "label 600m")
		check(GeoMath.approxDistanceLabel(1200) == "~1 km", "label 1200m")
		check(GeoMath.approxDistanceLabel(5000) == "~5 km", "label 5000m")

		print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
		exit(failures == 0 ? 0 : 1)
	}
}
