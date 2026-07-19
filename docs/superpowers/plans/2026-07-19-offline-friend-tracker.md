# Offline Friend Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user pick one group member and get a live heading-relative direction arrow + approximate distance toward that friend, using GPS coordinates flooded over the existing offline mesh.

**Architecture:** A new standalone `LocationManager` (`ObservableObject`) mirrors the `GroupManager` pattern — it consumes the existing `GroupPacketChannel` that `MessageBus` already conforms to, floods its own GPS coordinate as a new `.locationBeacon` packet, ingests peers' beacons, and computes bearing/distance to a chosen peer. Pure geometry (`GeoMath`) and a protocol-abstracted `DeviceLocationProvider` keep everything unit-testable with no CoreLocation linked. The concrete CoreLocation implementation and SwiftUI view are thin and build-verified only.

**Tech Stack:** Swift, SwiftUI, Combine, CoreLocation (concrete provider only), MultipeerConnectivity (unchanged, via existing bus).

## Global Constraints

- Do NOT modify existing behavior of transport, `MessageBus`, `GroupManager`, or any existing feature view. Additions only.
- New app-target source files go under `CupertinoCrew/CupertinoCrew/` — that folder is an Xcode **file-system synchronized root group**, so files there auto-join the `CupertinoCrew` target with NO `project.pbxproj` edits.
- Test files go under `CupertinoCrew/Tests/` — they are standalone `swiftc` programs, OUTSIDE the synchronized group and NOT in the app target.
- Test harness pattern (copy exactly): a `private var failures = 0`, `func check(_ cond: Bool, _ label: String)`, and `@main struct Runner { @MainActor static func main() { ...; exit(failures == 0 ? 0 : 1) } }`. Compile with `swiftc -parse-as-library`.
- New packet type is additive: whole fleet runs the same build, so a new `MeshMessageType` case is wire-safe.
- Bearing convention everywhere: degrees clockwise from **true north**, range `0..<360`.
- `LocationManager` and `DeviceLocationProvider` are `@MainActor` (matches `GroupManager`).
- Xcode build check command (used by non-unit tasks):
  `xcodebuild -project "CupertinoCrew/CupertinoCrew.xcodeproj" -scheme CupertinoCrew -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`

---

## File Structure

- Create `CupertinoCrew/CupertinoCrew/Location/GeoMath.swift` — `GeoCoordinate` struct + pure distance/bearing/label functions.
- Create `CupertinoCrew/CupertinoCrew/Location/LocationBeaconPayload.swift` — Codable wire payload.
- Create `CupertinoCrew/CupertinoCrew/Location/DeviceLocationProvider.swift` — provider protocol (no CoreLocation).
- Create `CupertinoCrew/CupertinoCrew/Location/LocationManager.swift` — coordinator (broadcast + ingest + `track`).
- Create `CupertinoCrew/CupertinoCrew/Location/CoreLocationProvider.swift` — concrete CoreLocation impl (build-only).
- Create `CupertinoCrew/CupertinoCrew/Location/FriendTrackerView.swift` — full-screen arrow UI.
- Modify `CupertinoCrew/CupertinoCrew/Mesh/MeshMessage.swift` — add `case locationBeacon`.
- Modify `CupertinoCrew/CupertinoCrew/CupertinoCrewApp.swift` — wire `LocationManager`.
- Modify `CupertinoCrew/CupertinoCrew/UI/SquadDetailView.swift` — add "Locate" per member row.
- Modify `CupertinoCrew/Info.plist` — add `NSLocationWhenInUseUsageDescription`.
- Create `CupertinoCrew/Tests/GeoMathTests.swift` — standalone geometry tests.
- Create `CupertinoCrew/Tests/LocationManagerTests.swift` — standalone coordinator tests.

> **Note on spec deviation:** the spec listed a `horizontalAccuracy` field on the beacon payload. It is dropped here (YAGNI) — nothing consumes it and the provider protocol does not expose accuracy. Payload carries `latitude`, `longitude`, `sampledAt` only.

---

### Task 1: GeoMath (pure geometry + distance label)

**Files:**
- Create: `CupertinoCrew/CupertinoCrew/Location/GeoMath.swift`
- Test: `CupertinoCrew/Tests/GeoMathTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct GeoCoordinate: Equatable { let latitude: Double; let longitude: Double }`
  - `enum GeoMath` with:
    - `static func distanceMeters(from: GeoCoordinate, to: GeoCoordinate) -> Double`
    - `static func initialBearingDegrees(from: GeoCoordinate, to: GeoCoordinate) -> Double` (0..<360, true north)
    - `static func approxDistanceLabel(_ meters: Double) -> String`

- [ ] **Step 1: Write the failing test**

Create `CupertinoCrew/Tests/GeoMathTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swiftc -parse-as-library CupertinoCrew/CupertinoCrew/Location/GeoMath.swift CupertinoCrew/Tests/GeoMathTests.swift -o /tmp/geomathtests && /tmp/geomathtests`
Expected: FAIL to compile — `GeoMath.swift` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `CupertinoCrew/CupertinoCrew/Location/GeoMath.swift`:

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swiftc -parse-as-library CupertinoCrew/CupertinoCrew/Location/GeoMath.swift CupertinoCrew/Tests/GeoMathTests.swift -o /tmp/geomathtests && /tmp/geomathtests`
Expected: PASS — final line `ALL PASSED`.

- [ ] **Step 5: Commit**

```bash
git add CupertinoCrew/CupertinoCrew/Location/GeoMath.swift CupertinoCrew/Tests/GeoMathTests.swift
git commit -m "feat: add GeoMath pure geometry + distance label"
```

---

### Task 2: Beacon payload + packet type

**Files:**
- Create: `CupertinoCrew/CupertinoCrew/Location/LocationBeaconPayload.swift`
- Modify: `CupertinoCrew/CupertinoCrew/Mesh/MeshMessage.swift` (add enum case near the Phase 5 additions block, ~line 48)

**Interfaces:**
- Consumes: `GeoCoordinate` (Task 1).
- Produces:
  - `MeshMessageType.locationBeacon`
  - `struct LocationBeaconPayload: Codable, Equatable { let latitude: Double; let longitude: Double; let sampledAt: Date; var coordinate: GeoCoordinate }`

- [ ] **Step 1: Add the enum case**

In `CupertinoCrew/CupertinoCrew/Mesh/MeshMessage.swift`, inside `enum MeshMessageType`, after `case system` (the last Phase 5 case), add:

```swift
	// --- Location tracking (additive; same-build fleet, so wire-safe) ---
	case locationBeacon
```

- [ ] **Step 2: Create the payload**

Create `CupertinoCrew/CupertinoCrew/Location/LocationBeaconPayload.swift`:

```swift
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
```

- [ ] **Step 3: Verify it compiles (folded into Task 3's test build)**

No standalone test for this task; correctness is exercised by Task 3's `LocationManager` tests, which encode/decode this payload. Sanity-compile now:

Run: `swiftc -parse -parse-as-library CupertinoCrew/CupertinoCrew/Location/GeoMath.swift CupertinoCrew/CupertinoCrew/Location/LocationBeaconPayload.swift`
Expected: no output (compiles clean).

- [ ] **Step 4: Commit**

```bash
git add CupertinoCrew/CupertinoCrew/Mesh/MeshMessage.swift CupertinoCrew/CupertinoCrew/Location/LocationBeaconPayload.swift
git commit -m "feat: add locationBeacon packet type + payload"
```

---

### Task 3: DeviceLocationProvider protocol + LocationManager coordinator

**Files:**
- Create: `CupertinoCrew/CupertinoCrew/Location/DeviceLocationProvider.swift`
- Create: `CupertinoCrew/CupertinoCrew/Location/LocationManager.swift`
- Test: `CupertinoCrew/Tests/LocationManagerTests.swift`

**Interfaces:**
- Consumes: `GeoCoordinate`, `GeoMath` (Task 1); `LocationBeaconPayload`, `MeshMessageType.locationBeacon` (Task 2); `GroupPacketChannel`, `MeshPacket` (existing).
- Produces:
  - `protocol DeviceLocationProvider: AnyObject` with `var currentCoordinate: GeoCoordinate? { get }`, `var currentHeadingDegrees: Double? { get }`, `var didUpdate: AnyPublisher<Void, Never> { get }`, `func start()`.
  - `struct PeerFix: Equatable { let coordinate: GeoCoordinate; let receivedAt: Date }`
  - `struct FriendTrack: Equatable { let bearingDegrees: Double; let distanceMeters: Double; let deviceHeadingDegrees: Double?; let isStale: Bool; var arrowRotationDegrees: Double }`
  - `final class LocationManager: ObservableObject` with `@Published private(set) var peerFixes: [String: PeerFix]`, `static let beaconTTL: TimeInterval` (30), `static let broadcastInterval: TimeInterval` (4), `init(channel:provider:)`, `func start()`, `func broadcastCurrentFix()`, `func track(_ peerID: String, now: Date = Date()) -> FriendTrack?`.

- [ ] **Step 1: Write the failing test**

Create `CupertinoCrew/Tests/LocationManagerTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run the compile command from the test file header comment.
Expected: FAIL to compile — `DeviceLocationProvider.swift` / `LocationManager.swift` do not exist.

- [ ] **Step 3: Write the provider protocol**

Create `CupertinoCrew/CupertinoCrew/Location/DeviceLocationProvider.swift`:

```swift
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
```

- [ ] **Step 4: Write the coordinator**

Create `CupertinoCrew/CupertinoCrew/Location/LocationManager.swift`:

```swift
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
```

- [ ] **Step 5: Run test to verify it passes**

Run the compile command from the test file header comment.
Expected: PASS — final line `ALL PASSED`.

- [ ] **Step 6: Commit**

```bash
git add CupertinoCrew/CupertinoCrew/Location/DeviceLocationProvider.swift CupertinoCrew/CupertinoCrew/Location/LocationManager.swift CupertinoCrew/Tests/LocationManagerTests.swift
git commit -m "feat: add LocationManager coordinator + provider protocol"
```

---

### Task 4: Concrete CoreLocation provider

**Files:**
- Create: `CupertinoCrew/CupertinoCrew/Location/CoreLocationProvider.swift`

**Interfaces:**
- Consumes: `DeviceLocationProvider`, `GeoCoordinate` (Tasks 1, 3).
- Produces: `final class CoreLocationProvider: NSObject, DeviceLocationProvider` (default `init()`).

No unit test — this is a thin CoreLocation adapter verified by the Xcode build. It is NOT included in any standalone `swiftc` test (those stay CoreLocation-free).

- [ ] **Step 1: Write the provider**

Create `CupertinoCrew/CupertinoCrew/Location/CoreLocationProvider.swift`:

```swift
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
```

- [ ] **Step 2: Verify the app target builds**

Run: `xcodebuild -project "CupertinoCrew/CupertinoCrew.xcodeproj" -scheme CupertinoCrew -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
Expected: `** BUILD SUCCEEDED **`. (If the named simulator is absent, substitute any installed iOS simulator from `xcrun simctl list devices`.)

- [ ] **Step 3: Commit**

```bash
git add CupertinoCrew/CupertinoCrew/Location/CoreLocationProvider.swift
git commit -m "feat: add CoreLocation-backed location provider"
```

---

### Task 5: FriendTrackerView (arrow UI)

**Files:**
- Create: `CupertinoCrew/CupertinoCrew/Location/FriendTrackerView.swift`

**Interfaces:**
- Consumes: `LocationManager` (environment object), `FriendTrack`, `GeoMath.approxDistanceLabel`, `String.shortPeerName` (existing extension used in `SquadDetailView`).
- Produces: `struct FriendTrackerView: View { init(peerID: String, displayName: String) }`.

No unit test (SwiftUI) — verified by the Xcode build in Task 6.

- [ ] **Step 1: Write the view**

Create `CupertinoCrew/CupertinoCrew/Location/FriendTrackerView.swift`:

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add CupertinoCrew/CupertinoCrew/Location/FriendTrackerView.swift
git commit -m "feat: add FriendTrackerView direction arrow UI"
```

(Build verification happens in Task 6 once the view is wired and reachable.)

---

### Task 6: Wire LocationManager into the app + Info.plist

**Files:**
- Modify: `CupertinoCrew/CupertinoCrew/CupertinoCrewApp.swift` (`MainAppView`, lines ~25-43)
- Modify: `CupertinoCrew/Info.plist`

**Interfaces:**
- Consumes: `LocationManager`, `CoreLocationProvider` (Tasks 3, 4).
- Produces: `LocationManager` available as an `@EnvironmentObject` to the whole view tree.

- [ ] **Step 1: Add the usage-description key to Info.plist**

In `CupertinoCrew/Info.plist`, inside the top-level `<dict>`, add:

```xml
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>District uses your location to point you toward friends in your group over the offline mesh.</string>
```

- [ ] **Step 2: Wire LocationManager in MainAppView**

In `CupertinoCrew/CupertinoCrew/CupertinoCrewApp.swift`, replace the `MainAppView` struct (lines ~25-43) with:

```swift
struct MainAppView: View {
    @StateObject private var bus: MessageBus
    @StateObject private var groups: GroupManager
    @StateObject private var location: LocationManager
    @StateObject private var wallet = WalletManager()

    init(userName: String) {
        let bus = MessageBus(transport: MultipeerTransport(displayName: userName))
        _bus = StateObject(wrappedValue: bus)
        _groups = StateObject(wrappedValue: GroupManager(channel: bus))
        _location = StateObject(wrappedValue: LocationManager(channel: bus, provider: CoreLocationProvider()))
    }

    var body: some View {
        ContentView()
            .environmentObject(bus)
            .environmentObject(groups)
            .environmentObject(location)
            .environmentObject(wallet)
            .onAppear {
                bus.start()
                location.start()
            }
    }
}
```

- [ ] **Step 3: Verify the app builds**

Run: `xcodebuild -project "CupertinoCrew/CupertinoCrew.xcodeproj" -scheme CupertinoCrew -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add CupertinoCrew/CupertinoCrew/CupertinoCrewApp.swift CupertinoCrew/Info.plist
git commit -m "feat: wire LocationManager into app + location usage string"
```

---

### Task 7: "Locate" entry from squad member list

**Files:**
- Modify: `CupertinoCrew/CupertinoCrew/UI/SquadDetailView.swift` (member `ForEach`, lines ~144-168; plus the view's environment objects and a presentation state)

**Interfaces:**
- Consumes: `LocationManager` (environment object), `FriendTrackerView` (Task 5).
- Produces: a per-member "Locate" button that presents `FriendTrackerView` for that member.

- [ ] **Step 1: Add the environment object + presentation state**

In `CupertinoCrew/CupertinoCrew/UI/SquadDetailView.swift`, at the top of `struct SquadDetailView`, alongside the existing `@EnvironmentObject var groups`, add:

```swift
    @EnvironmentObject var location: LocationManager
    @State private var trackedMember: String?
```

- [ ] **Step 2: Add the Locate button to each member row**

In the member `ForEach` (`ForEach(Array(group.members).sorted(), id: \.self) { member in`), inside the `HStack`, after the existing `if isLeader && member != groups.localPeerID { … }` Remove button block, add a Locate button for every member except yourself:

```swift
                                    if member != groups.localPeerID {
                                        Button("Locate") {
                                            trackedMember = member
                                        }
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(red: 0.2, green: 0.9, blue: 0.6).opacity(0.25))
                                        .foregroundStyle(Color(red: 0.2, green: 0.9, blue: 0.6))
                                        .clipShape(Capsule())
                                    }
```

- [ ] **Step 3: Present the tracker**

Attach a `.fullScreenCover` to the view. Add this modifier to the outermost view returned by `SquadDetailView.body` (the same level where existing modifiers like navigation are applied):

```swift
        .fullScreenCover(item: Binding(
            get: { trackedMember.map { TrackedPeer(id: $0) } },
            set: { trackedMember = $0?.id }
        )) { peer in
            NavigationStack {
                FriendTrackerView(peerID: peer.id, displayName: peer.id.shortPeerName)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { trackedMember = nil }
                        }
                    }
            }
        }
```

And add this small Identifiable wrapper at file scope (bottom of `SquadDetailView.swift`, outside the struct), since `fullScreenCover(item:)` needs an `Identifiable`:

```swift
/// Wraps a peer ID so it can drive `fullScreenCover(item:)`.
private struct TrackedPeer: Identifiable {
	let id: String
}
```

- [ ] **Step 4: Verify the app builds**

Run: `xcodebuild -project "CupertinoCrew/CupertinoCrew.xcodeproj" -scheme CupertinoCrew -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Manual smoke test (two real devices)**

CoreLocation + Multipeer need real hardware. On two iPhones both signed in with different names and in the same group:
1. Open the app on both; grant location "While Using".
2. On device A open the squad, tap **Locate** on device B's row.
3. Confirm the arrow appears with an approximate distance, rotates as device A physically turns, and updates as device B moves. Walking toward the arrow should shrink the distance bucket.

- [ ] **Step 6: Commit**

```bash
git add CupertinoCrew/CupertinoCrew/UI/SquadDetailView.swift
git commit -m "feat: add Locate action to squad member rows"
```

---

## Self-Review

**Spec coverage:**
- Offline GPS coords → Tasks 1-4 (GeoMath, payload, provider, CoreLocation). ✓
- Flood + multi-hop forward → reuses existing bus via `channel.send`; Task 3. ✓
- Heading-relative arrow + approx distance → `FriendTrack.arrowRotationDegrees` (Task 3) + `FriendTrackerView` (Task 5). ✓
- One selected target only → `track(peerID)` + `fullScreenCover` for a single member (Tasks 3, 7). ✓
- Always-on broadcast → `LocationManager.start()` timer (Tasks 3, 6). ✓
- Entry from squad member list → Task 7. ✓
- Error/stale/no-heading/no-fix states → `FriendTrackerView` (Task 5), `CoreLocationProvider` failure handling (Task 4). ✓
- Info.plist usage string → Task 6. ✓
- Tests → Tasks 1, 3. ✓
- No existing behavior changed → all modifications additive (enum case, new StateObject, new row button, plist key). ✓

**Placeholder scan:** none — every code step carries full code; no TBD/TODO.

**Type consistency:** `GeoCoordinate`, `LocationBeaconPayload`, `PeerFix`, `FriendTrack`, `DeviceLocationProvider`, `LocationManager.track/broadcastCurrentFix/start`, `beaconTTL`, `broadcastInterval` used consistently across Tasks 1-7. `FakeChannel`/`FakeProvider` match the protocols they implement. `.locationBeacon` used identically in Tasks 2, 3, 5-equivalent paths.
