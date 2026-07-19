# Offline Friend Tracker — Design

**Date:** 2026-07-19
**Status:** Approved design, pending implementation plan
**Author:** Paarth Singh (with Claude)

## Goal

Let a user pick one member of a group and get a live **direction to move** toward
that friend — a rotating arrow plus an approximate distance — using GPS that works
fully offline. No map, no route, no exact path: just "which way and roughly how far".

Coordinates travel over the existing Multipeer mesh (flood + multi-hop forward +
dedup + TTL). No internet is ever used; GPS is satellite-based and needs no network.

## Non-goals

- No map rendering, turn-by-turn routing, or polyline path.
- No exact-address / reverse-geocoding.
- No background-mode location (foreground app run only).
- No changes to existing features (discovery, tickets, chat/squad, wallet, developer
  mesh). Only additive files + minimal wiring.

## Constraints & decisions (from brainstorming)

| Decision | Choice |
|----------|--------|
| Location sharing scope | Plain mesh flood — own coords go to connected peers, who forward to their peers (normal `MeshPacket` multi-hop). No unicast, no ACK. |
| Direction UI | Heading-relative arrow (rotates with device compass) + approx distance. Treasure-hunt style. |
| Targets shown | Only the **one** group member the user selects. All other peers' fixes ignored for display. |
| Emit trigger | Device broadcasts its own coords the whole time the app runs. |
| Entry point | From the squad member list (`SquadDetailView`): each member row gets a "Locate" action → full-screen tracker. |

## Architecture

New standalone `LocationManager` that mirrors the proven `GroupManager` pattern:
it consumes the existing `GroupPacketChannel` surface `MessageBus` already conforms to
(`localPeerID`, `groupInbox`, `send`). It **never relays** — the bus already floods
every packet; `LocationManager` only originates its own beacons and reads inbound ones,
exactly like `GroupManager` reads group packets. Transport, routing, bus, and
`GroupManager` are untouched.

### Components (each one job, independently testable)

1. **`LocationBeaconPayload`** (Codable)
   - Fields: `latitude: Double`, `longitude: Double`, `horizontalAccuracy: Double`,
     `sampledAt: Date`.
   - Sender identity is the enclosing `MeshPacket.originPeerID` — not duplicated in payload.

2. **`DeviceLocationProvider`** (protocol + concrete `CLLocationManager` impl)
   - Publishes the latest `CLLocation` and device true heading (`CLHeading`).
   - Requests "When In Use" authorization.
   - Protocol-ized so unit tests and the simulator inject a fake with scripted fixes.

3. **`GeoMath`** (pure functions, no dependencies)
   - `distanceMeters(from:to:)` — haversine.
   - `initialBearingDegrees(from:to:)` — great-circle initial bearing (0–360, 0 = true north).
   - Fully unit-testable against known coordinate pairs.

4. **`LocationManager`** (`ObservableObject`)
   - Holds `channel: GroupPacketChannel` and `provider: DeviceLocationProvider`.
   - **Broadcast:** a repeating timer (~4 s) encodes the current fix as a
     `LocationBeaconPayload` and calls `channel.send(MeshPacket(type: .locationBeacon,
     priority: .normal, validFor: 30, payload: ...))`. Skips emit while no GPS fix yet.
   - **Ingest:** subscribes to `channel.groupInbox`, filters `type == .locationBeacon`,
     decodes, stores `peerFixes[packet.originPeerID] = PeerFix(coordinate, receivedAt: Date())`.
   - **Query:** `track(peerID) -> FriendTrack?` combining own latest fix + heading with the
     target's latest fix → `(bearingDegrees, distanceMeters, isStale, deviceHeading)`.
     Returns `nil` when own fix or target fix is missing.
   - `isStale` = target fix older than the 30 s beacon TTL.

5. **`FriendTrackerView`** (SwiftUI, full-screen)
   - Big arrow rotated by `targetBearing − deviceHeading`.
   - Approx distance label, coarse-bucketed (`~10 m`, `~50 m`, `~200 m`, `~1 km`).
   - Named for the selected member via `member.shortPeerName`.

### New packet type

Add one case to `MeshMessageType`: `case locationBeacon`. Additive; the whole fleet
runs the same build so a new enum case is safe. Existing frozen cases
(`compassPairing`, `compassRange`) are left as-is.

## Data flow

**Outbound (always-on):**
`CLLocationManager` fix → `DeviceLocationProvider` publishes `CLLocation`
→ `LocationManager` timer encodes `LocationBeaconPayload`
→ `MeshPacket(type: .locationBeacon, priority: .normal, validFor: 30)`
→ `bus.send(_:)` → floods + multi-hop forwards. No `destinationPeerID` ⇒ no ACK path.

**Inbound:**
`bus.inbox` → `LocationManager` filters `.locationBeacon` → decode
→ `peerFixes[originPeerID] = PeerFix(coord, receivedAt: now)`.
Bus already deduped + relayed; `LocationManager` only reads.

**Render (one target only):**
`FriendTrackerView(selectedPeerID)` → `LocationManager.track(peerID)`
→ own fix + heading + target fix → `(bearing, distance, isStale)` → rotating arrow.
Other peers' fixes are not displayed.

## UI / entry point

`SquadDetailView` member list (`ForEach` at ~line 144): each member row, except the
local peer, gains a "Locate" affordance that presents `FriendTrackerView` for that
member's peerID. Only a button/navigation is added to the existing row — no change to
membership logic, remove-member action, or invite flow.

## Error handling

| Condition | Behavior |
|-----------|----------|
| Location auth denied/restricted | Tracker shows "Enable location in Settings"; broadcaster emits nothing. Other features unaffected. |
| No magnetometer / heading unavailable | Arrow falls back to a north-up bearing label ("Friend is NE") with a small note. |
| Target not sharing or stale >30 s | "Waiting for friend's signal", arrow dimmed. |
| Own GPS not yet fixed | "Getting your location…". |

## Info.plist

Add `NSLocationWhenInUseUsageDescription` (required — iOS crashes on a location
request without it). Additive key only.

## Testing

`Tests/` directory already exists.

- **`GeoMath`** — haversine distance and initial bearing verified against known
  coordinate pairs (e.g. established city-to-city distance/bearing values).
- **`LocationManager`** — fake `GroupPacketChannel` + fake `DeviceLocationProvider`:
  - Feed inbound `.locationBeacon` packets → assert `peerFixes` keyed by `originPeerID`.
  - Assert `track()` returns correct bearing/distance and `isStale` transitions after TTL.
  - Advance the fake provider's fix → assert exactly one `.locationBeacon` packet is sent.
- No CoreLocation in tests — everything sits behind the provider protocol.

## Wiring summary (additive)

- `MainAppView.init`: construct `LocationManager(channel: bus, provider: DeviceLocationProvider())`,
  hold as `@StateObject`, inject via `.environmentObject`, start in `.onAppear`.
- `ContentView`: unchanged (entry is via squad detail, not a new tab).
- `SquadDetailView`: add "Locate" affordance per member row.
- `MeshMessageType`: one new case `locationBeacon`.
- `Info.plist`: one new usage-description key.

All existing code paths remain byte-for-byte on the wire and behaviorally unchanged.
