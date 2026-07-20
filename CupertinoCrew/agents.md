# agents.md — District Offline Mesh Add-on

> **Single source of truth for all workhorse agents. Read this file FIRST, every session.**

## Instructions to Agents (read before doing anything)

1. **Read this file top to bottom before starting work.** Then read `implementation-plan.md` and `srd.md` for full context. You have no other context — assume nothing that isn't written down.
2. **Pick up only tasks whose dependencies are all `done`** and whose phase gate (see Gates) is open.
3. **Before ending a session:** update the status tag of every task you touched, append to the Completed Log and/or In Progress / Next Up sections. Never restructure this file — only append and update tags.
4. **Never mark a task `done` without a "Verified by:" note** in the Completed Log (what test, what device count, what output proved it).
5. **If blocked, set status `blocked`, write the blocker in In Progress / Next Up, and stop.** Do not guess past a blocker, especially a legal gate.
6. **No code in planning docs; no undocumented decisions in code.** Any decision that changes the plan/SRD gets a line in the Decisions Log.
7. Feature IDs (F0–F4), phase numbers, requirement IDs (FR-*/NFR-*), and open questions (OQ-*) are shared vocabulary across all three documents — use them, don't invent synonyms.

## Project Summary

Offline-first add-on to the **District** iOS app for large events where cellular collapses. Architecture shifts client-server → **P2P mesh** (store-and-forward messaging, pre-event caching, hybrid re-sync). Five components: **F0 Mesh Core** (shared infra), **F1 Offline Wallet**, **F2 Lost Friend Compass**, **F3 Excess Harvest Pipeline**, **F4 Emergency Overrides ("God Mode")**.

Full context: `implementation-plan.md` (phasing & rationale) · `srd.md` (requirements).

## Gates (phase cannot start/ship until gate is `OPEN`)

- [x] `GATE-TRANSPORT` — transport decided: Multipeer Connectivity, native, no fallback (OQ-1 resolved). Status: **OPEN**
- [ ] `GATE-WALLET-LEGAL` — legal/compliance + App Store sign-off (OQ-2, OQ-3) → blocks Phase 4. Status: **CLOSED**
- [ ] `GATE-COMPASS-PRIVACY` — privacy review sign-off (OQ-4) → blocks F2 beta ship. Status: **CLOSED**
- [ ] `GATE-GODMODE-POSITIONING` — safety-positioning decision (OQ-5) → blocks F4 launch copy/contracts (not F4 engineering). Status: **CLOSED**

---

## Task List

Status tags: `[not started]` `[in progress]` `[blocked]` `[done]` · Owner: `TBD` for all.

### Phase 0 — Spikes, Decisions & Compliance Kickoff
- `P0-01` [not started] (TBD) Transport characterization spike: measure Multipeer Connectivity limits (peer ceilings→OQ-7, background behavior→OQ-6, crowd range, reconnection); write report. Transport already decided; GATE-TRANSPORT is OPEN. Deps: —
- `P0-02` [not started] (TBD) Crowd propagation field spike (20+ devices); report with hop latency, delivery %, dead zones. Deps: —
- `P0-03` [not started] (TBD) Battery drain spike; set mesh duty-cycle budget. Deps: —
- `P0-04` [not started] (TBD) F2 ranging feasibility spike (UWB vs. RSSI); device capability matrix. Deps: —
- `P0-05` [not started] (TBD) Open legal/compliance review for F1 (OQ-2, OQ-3); record owner + ETA. Deps: —
- `P0-06` [not started] (TBD) Open privacy review for F2 (OQ-4); record owner + ETA. Deps: —
- `P0-07` [not started] (TBD) Open F4 safety-positioning review (OQ-5); record owner + ETA. Deps: —

### Phase 1 — F0 Mesh Core
- `P1-01` [in progress] (TBD) Transport abstraction layer over Multipeer Connectivity (informed by P0-01 characterization). Deps: P0-01
- `P1-02` [in progress] (TBD) Store-and-forward message bus: IDs, priority classes, TTL, dedupe, persistence. Deps: P1-01
- `P1-03` [not started] (TBD) Pre-event caching pipeline: map, menus, schedule, organizer keys; versioned + integrity-checked. Deps: —
- `P1-04` [not started] (TBD) Hybrid re-sync framework (generic upload/download on regained connectivity). Deps: P1-02
- `P1-05` [in progress] (TBD) Diagnostics/telemetry screen: peers, queues, hops, delivery. Deps: P1-02
- `P1-06` [not started] (TBD) Phase 1 exit field test (10+ devices, ≥95% delivery, offline catch-up, cache offline, battery in budget). Deps: P1-01..P1-05, P0-02, P0-03

### Phase 2 — F4 Emergency Overrides + F3 Excess Harvest
- `P2-01` [not started] (TBD) F4 organizer authoring flow: signed alerts (type, severity, body, validity window). Deps: P1-06, P1-03
- `P2-02` [not started] (TBD) F4 attendee alert UX: full-screen, sound/haptics by severity, ack, history. Deps: P2-01
- `P2-03` [not started] (TBD) F4 top-priority propagation + preemption over mesh. Deps: P1-02, P2-01
- `P2-04` [not started] (TBD) F4 delivery/ack observability back to organizer. Deps: P2-03, P1-04
- `P2-05` [not started] (TBD) F3 vendor Surplus Alert broadcast (items, qty, price/free, location, expiry). Deps: P1-06
- `P2-06` [not started] (TBD) F3 attendee/staff surfacing + claim/confirm flow + auto-expiry. Deps: P2-05
- `P2-07` [not started] (TBD) F0 hardening: loop suppression, storm damping, TTL tuning from field data. Deps: P2-03, P2-06
- `P2-08` [not started] (TBD) Phase 2 exit field test (≥20 devices, F4 ≥99% delivery, preemption proven, F3 end-to-end offline, tamper rejection). Deps: P2-01..P2-07

### Phase 3 — F2 Lost Friend Compass
- `P3-01` [not started] (TBD) Pairing & consent flow (mutual, revocable) per draft privacy model. Deps: P1-06, P0-06
- `P3-02` [not started] (TBD) Ranging engine: UWB precise mode + RSSI degraded mode + smoothing; honest mode indicator. Deps: P0-04, P3-01
- `P3-03` [not started] (TBD) Session battery discipline: time-bound sessions, duty cycling per P0-03 budget. Deps: P3-02
- `P3-04` [not started] (TBD) Verify zero retention/upload of ranging data (inspection + re-sync audit). Deps: P3-02
- `P3-05` [not started] (TBD) Phase 3 exit field test: find-each-other in dense crowd, both modes; battery measured. Deps: P3-01..P3-04
- `P3-06` [blocked] (TBD) F2 beta ship. Deps: P3-05, GATE-COMPASS-PRIVACY

### Phase 4 — F1 Offline Wallet  ⚠️ entire phase blocked on GATE-WALLET-LEGAL
- `P4-01` [blocked] (TBD) Vault load & lock: pre-event funding, secure local balance + signing credentials. Deps: GATE-WALLET-LEGAL, P1-03
- `P4-02` [blocked] (TBD) Voucher purchase protocol: charge request → approval → signed single-use voucher → vendor verify → balance decrement. Deps: P4-01
- `P4-03` [blocked] (TBD) Vendor iPad experience: charge, confirm, offline sales log, day summary. Deps: P4-02
- `P4-04` [blocked] (TBD) Data-mule specialization of re-sync: silent, encrypted, rate/battery-budgeted relay upload. Deps: P1-04, P4-02
- `P4-05` [blocked] (TBD) Reconciliation + conflict detection + dispute pipeline per legal-approved policy. Deps: P4-04
- `P4-06` [blocked] (TBD) Adversarial test suite: replay, tamper, forced double-spend detection. Deps: P4-05
- `P4-07` [blocked] (TBD) Phase 4 exit: end-to-end offline commerce demo + vendor day-in-the-life (20+ tx). Deps: P4-01..P4-06

### Phase 5 — Hardening & Launch
- `P5-01` [not started] (TBD) Scale field trial at real event (hundreds of devices, all features, all NFRs measured). Deps: P2-08, P3-05, P4-07
- `P5-02` [not started] (TBD) Failure-mode drills: dead zones, mass join/leave, vendor crash mid-tx, mesh fuzzing. Deps: P5-01
- `P5-03` [not started] (TBD) Final performance/battery tuning to SRD NFR numbers. Deps: P5-01
- `P5-04` [not started] (TBD) App Store submission dry run incl. wallet-flow documentation. Deps: P4-07, GATE-WALLET-LEGAL
- `P5-05` [not started] (TBD) Operational readiness: organizer/vendor onboarding, support & dispute runbooks, alert-misuse incident process. Deps: P2-08, P4-07
- `P5-06` [not started] (TBD) Go/no-go launch review; all gates OPEN, all P0 requirements verified. Deps: P5-01..P5-05, all gates

---

## Completed Log

> Append-only. One line per completed task: `date · task ID · agent · Verified by: <how>`.

_(empty — no work has started)_

## In Progress / Next Up

> Update every session. List: what you're on, expected next step, and any blockers (with the gate/OQ ID).

- 2026-07-18 · Hackathon Step 1 (F0 transport + message bus) code complete and builds clean for a real iOS device (`xcodebuild -destination 'generic/platform=iOS' build` → BUILD SUCCEEDED, no warnings). **Not yet marked `[done]`** — no on-device pairing/delivery test has been run. Next step: install on 2+ physical iPhones (cellular off), use the "Send test ping" button in the diagnostics screen (ContentView), confirm peer count updates live and the ping appears on the other device(s) with correct hop count; then re-verify store-and-forward by toggling one phone to Airplane Mode during a send and confirming it receives on reconnect. Once that passes, flip P1-01/P1-02 to `[done]` with a proper "Verified by" line here, then move to Step 2 (God Mode / F4 demo).
- Confirmed iPhone fleet: all 3–4 test devices are iPhone 11 or later, non-SE → all UWB-capable (U1/U2), so Step 4 (Compass) can target precise mode as the primary path; still implement the RSSI/distance-only fallback code path defensively since real hardware confirmation happens per-device at runtime, not by model lookup.
- 2026-07-19 · Phase 1 runtime diagnostics implemented: structured local logs now cover discovery, invitations, browser/advertiser state, session state, packets, relays, duplicates, routing destinations, reconnect attempts, and backlog queue depth. Next step: run the existing two-device physical pairing and delivery verification before marking diagnostics complete; no automated test target exists in this project.

## Decisions Log

> Append-only. Any decision that changes plan/SRD: `date · decision · rationale · docs updated`.

- 2026-07-18 · Transport is Apple Multipeer Connectivity (native iOS); Bridgefy dropped, no third-party mesh SDK, no fallback transport · Decided by stakeholders ahead of the P0-01 spike; resolves OQ-1 · Updated: implementation-plan.md (Transport Decision section, P0-01, Phase 1 deps), srd.md (System Overview, C-02, OQ-1 marked RESOLVED), agents.md (GATE-TRANSPORT OPEN, P0-01)
- 2026-07-18 · **Hackathon scope override (this prompt supersedes agents.md/implementation-plan.md/srd.md phasing where they conflict).** Build order collapses Phase 0 spikes, Phase 1 exit criteria (10-device/95%/4hr-battery field test), and most of Phases 2–4 into a tight 4-demo sequence: (1) F0 transport+bus with a status strip, (2) F4 God Mode 3-phone demo, (3) F1 Offline Wallet 2-phone demo with **play money only, no processor, no central ledger** (direct customer→vendor, GATE-WALLET-LEGAL/OQ-2/OQ-3 concerns explicitly deferred — not resolved, just out of scope for this build), (4) F2 Compass 2-phone demo (privacy review OQ-4 similarly deferred, not resolved). Pre-event caching pipeline (P1-03), hybrid re-sync (P1-04), F3 Excess Harvest, and all Phase 5 hardening are **not built** in this pass. Rationale: hackathon time budget; real-device-only demo value over spec completeness. Docs not restructured — this entry is the record of the deviation. Owner must reconcile task statuses against full phased plan before any production continuation.
- 2026-07-18 · **Real-device-only, no fallback/mock transport.** Per this prompt: 3–4 physical iPhones, no simulators, no Mac-as-node. All demo values (peer counts, distances, balances, alert delivery) must originate from live over-the-air Multipeer traffic — no hardcoded/scripted data at any layer. Reinforces existing C-02/OQ-1 resolution; adds the "no simulator" and "no scripted demo data" constraints which the base docs didn't specify.
- 2026-07-18 · Fixed malformed `PRODUCT_BUNDLE_IDENTIFIER` (`com..CupertinoCrew`, empty org segment) → `com.cupertinocrew.CupertinoCrew`; required for real-device code signing. Also switched `GENERATE_INFOPLIST_FILE` from YES to a real `Info.plist` (moved to project root, outside the Xcode 16 synchronized source folder, to avoid a "multiple commands produce Info.plist" build collision) so `NSBonjourServices` (array-valued, needed for `_district-mesh._tcp`/`_udp`), `NSLocalNetworkUsageDescription`, and `NSNearbyInteractionUsageDescription` could be declared — none of these are expressible as flat `INFOPLIST_KEY_*` build settings.

## Engineering Handoff — 2026-07-19

### Phase 1 completion — Runtime Diagnostics

- Structured local `os.Logger` diagnostics were added for discovery, peer loss, invitations, advertiser/browser state, MCSession state, packet send/receive, relay, duplicate drops, retry/backlog state, reconnects, decoding, task boundaries, actor hops, and callback entry/exit.
- Every diagnostic includes timestamp, local/remote peer IDs, thread, session ID, function, session state, packet type, and packet size where available.
- Phase 1 code is complete and builds for a generic iOS device. Physical pairing/delivery verification remains outstanding, so P1-01/P1-02/P1-05 are intentionally not marked `[done]`.

### Phase 2 completion — Transport Hardening

- `MultipeerTransport` retains exactly one `MCSession`, advertiser, and browser per transport instance.
- Start/stop is idempotent; duplicate invites are suppressed; pending invites are cancelled on timeout, peer loss, or stop; reconnect scheduling is serialized; MCSession send failures are logged and propagated.
- Phase 2 code is complete and builds for a generic iOS device. Physical two-/three-device verification remains outstanding, so the formal field-test task is not marked `[done]`.

### Phase 2 regression and resolution

- Regression: Device C could terminate while joining an existing A↔B mesh, while A and B remained functional.
- Root cause analysis: debug assertions in `MultipeerTransport.session(_:peer:didChange:)` treated duplicate `.connected` callbacks or a delayed `.connected` callback after shutdown/restart as fatal. Multipeer callback ordering can make either condition observable during concurrent invitation/restart activity.
- Fix: removed the crash-producing assertions and replaced them with structured `session_state_duplicate` and `session_state_invalid` diagnostics. No routing or transport decision was changed.
- Current known behavior: the app builds successfully; runtime Device C confirmation requires reproducing on physical devices and collecting the new callback-boundary logs/crash report. The latest tracing build records the exact last callback/task/decode/send line reached before termination.

### Remaining implementation roadmap

1. Complete the targeted Phase 3 memory-safety and concurrency audit; fix only confirmed ownership, cancellation, isolation, collection, or Data-pressure issues.
2. Run physical two-device and three-device mesh verification with diagnostics captured from every device.
3. Reconcile P1/P2 task statuses only after device-count verification and add `Verified by:` entries.
4. Continue with the hackathon demo sequence documented in the Decisions Log, while preserving the legal/privacy gates for wallet and compass work.
5. Do not start the full production Phase 4 wallet work until `GATE-WALLET-LEGAL` is open.

## Engineering Handoff — Phase 3 Memory Safety & Concurrency Audit — 2026-07-19

### Objective and result

Audited Task lifetime/cancellation, actor boundaries, delegate and closure ownership, Combine subscriptions, mutable collections, and Data serialization. One confirmed issue was fixed; other areas were reviewed and left unchanged because no evidence justified a behavioral change.

### Files modified for Phase 3

- `CupertinoCrew/CupertinoCrew/Mesh/MessageBus.swift` — tracked one cancellable backlog Task per peer, cancelled/replaced stale tasks, cancelled all remaining tasks in `deinit`, added cancellation checks, and made `Task.sleep` cancellation explicit. This prevents orphaned or overlapping backlog tasks without changing message format or routing.
- `agents.md` — appended this handoff and preserved all prior history.

### Audit findings

- No `Task.detached` or recursive Task creation exists.
- `MessageBus` is `@MainActor`; its collections and Combine-driven mutations are main-isolated.
- Transport state mutations are serialized through the existing main-queue lifecycle paths, with session-state diagnostics protected by `NSLock`.
- Delegates are assigned once; weak captures are used by path, timer, restart, and task closures; no NotificationCenter observers or timers were found.
- Combine subscriptions use weak captures and are owned by `MessageBus`; no retain cycle was confirmed.
- Message Data is passed with copy-on-write semantics and decoded once per incoming packet. No unnecessary buffer or repeated decode was found.

### Remaining risks

- Physical two-device and three-device regression tests have not been run in this environment.
- Multipeer callback queue behavior still needs confirmation on real devices under simultaneous joins/restarts.
- Persistence write failures and backlog encode failures remain best-effort by design and should be made observable before production hardening if the scope permits.
- The formal P1/P2 task statuses remain unchanged because no device-count verification with `Verified by:` evidence exists.

### Current architecture status

The architecture remains one `MCSession`, one advertiser, one browser, a `MeshTransport` abstraction, a `@MainActor` store-and-forward `MessageBus`, and local structured diagnostics. Public APIs and routing behavior are preserved.

### Testing completed

- `git diff --check` passed.
- Generic iOS build passed: `** BUILD SUCCEEDED **`.
- No automated test target exists.
- No physical mesh test was completed; the existing AppIntents metadata warning is unrelated to these changes.

### Outstanding TODOs

- Run and capture two-device and three-device physical mesh tests.
- Reconcile P1/P2 statuses only after those tests.
- Decide whether persistence/encoding best-effort failures need a bounded retry/error surface.

### Recommended Phase 4 work

Perform routing verification only: packet UUID deduplication, TTL/hop limits, relay exclusion, group/broadcast behavior, late joins, partitions, and rejoins. Keep the current architecture and diagnostics. Do not begin the production wallet phase until `GATE-WALLET-LEGAL` is open.

## Engineering Handoff — Phase 5: Mesh Protocol Evolution & Reliability — 2026-07-19

### Scope and result

Protocol-layer work only. Transport (`MultipeerTransport`), routing (flood + dedup + TTL), memory-safety, and diagnostics from Phases 1–4 are preserved and continue to behave exactly as before. No feature logic (groups, discovery, wallet, navigation) was implemented — only the extensible protocol scaffolding those features will plug into. No UI was redesigned.

**Architectural decision (compatibility):** the packet type was evolved *additively*, never rewritten. The struct was renamed `MeshMessage` → `MeshPacket` with `typealias MeshMessage = MeshPacket` so every existing call site compiles unchanged. All original stored properties keep their names, so the JSON wire format is a strict superset of the old one. New fields are `Optional`, so Swift's synthesized `Codable` encodes them via `encodeIfPresent` (omitted when nil) and decodes via `decodeIfPresent` (absent → nil). Consequences, verified by test:
- New build → old build: extra keys are ignored by the old decoder; required keys all still present.
- Old build → new build: missing new keys decode to nil.
- The struct rename is invisible on the wire (JSON keys, not Swift type names, are what travels).

### New protocol fields (`Mesh/MeshMessage.swift`)

`MeshPacket` gained three optional, wire-compatible fields:
- `previousHopPeerID: String?` — stable ID of the peer the packet was received from on the last hop; stamped by the relayer on each forward (nil on a freshly originated packet).
- `destinationPeerID: String?` — optional unicast destination. nil = broadcast/flood to everyone (the only legacy behavior). When set and it equals the local peer, the bus treats the packet as delivered to its final destination and emits an ACK.
- `groupID: String?` — carried but NOT interpreted yet; reserved for Phase 6 group scoping.

Read-only vocabulary aliases were added so spec/feature code can use the requested names without changing the wire: `packetID` (→ `id`), `sourcePeerID` (→ `originPeerID`), `packetType` (→ `type`), `timestamp` (→ `createdAt`). Helpers: `isAddressed(to:)` (true only for a non-ACK packet whose destination is the local peer) and `relayed(previousHop:)`.

### Packet type system

`MeshMessageType` kept all Phase 1–4 cases with their frozen raw values and added: `text`, `heartbeat`, `ack`, `groupInvite`, `groupAccept`, `groupLeave`, `discovery`, `payment`, `paymentConfirmation`, `system`. Spec `UPPER_SNAKE` names map to these camelCase cases (mapping documented in-file). Only `.ack` has behavior wired this phase; the rest are inert scaffolding — the bus floods/dedups/expires them uniformly like any other type.

### Hop count behavior

- Increment happens in exactly one place: `MeshPacket.relayed(previousHop:)`, called once per relay in `MessageBus.handleIncoming`. Origin `send()` never increments.
- Value semantics guarantee relaying produces a new copy and never mutates the received packet.
- Exposed to upper layers via the public `MeshPacket.hopCount` (and every accepted packet is delivered through `MessageBus.inbox`).
- In diagnostics: `stats.recordHopCount(_:)` folds each *inbound* packet's hop count (the value as received, before relay increment) into running average + maximum. In logging: `packet_received` and `packet_relay` events carry `hopCount`; relay also logs `previousHop`.
- A relayed copy that reaches the hop/TTL budget (`isExpired`) is no longer broadcast — this trims a wasted send that old receivers would have dropped anyway (delivery reach is unchanged; it also bounds flood storms). Logged as `packet_dropped` / reason `hop_budget_exhausted`.

### ACK architecture (`Mesh/MessageBus.swift`)

Acknowledgement *infrastructure only — no automatic retries this phase.*
- Outbound: `send()` on a directed, non-ACK packet (`destinationPeerID != nil`) registers a `PendingAck` and arms a timeout task (`ackTimeout = 30s`).
- Delivery: when an inbound packet `isAddressed(to: localPeerID)`, the bus emits an `.ack` packet whose payload is an `AckPayload { acknowledgedPacketID }`, destined for the original source. ACKs flood back through the mesh (multi-hop) exactly like any packet; loops are bounded by the existing `seenIDs` dedup and `maxHops`.
- Inbound ACK: only the true origin (`destinationPeerID == localPeerID`) consumes it — cancels the timeout, moves the id from pending → `acknowledgedPacketIDs`. Intermediate nodes just relay it.
- Timeout: if the window elapses unacknowledged, the id moves to `timedOutPacketIDs`. No resend is attempted (deferred to a later phase).
- State exposed read-only: `acknowledgedPacketIDs`, `timedOutPacketIDs`; pending count via `dashboard`.
- Note: the diagnostics "Send test ping" packets carry no `destinationPeerID`, so they never trigger ACKs — the existing ping demo is unaffected.

### Diagnostics additions (`Mesh/MeshStats.swift`, new)

`MeshStats` (plain value type, mutated only on the `@MainActor` bus, all O(1)): `packetsSent`, `packetsReceived`, `packetsRelayed`, `packetsDelivered`, `packetsAcknowledged`, `packetsExpired`, `packetsDropped`, `duplicatePackets`, `averageHopCount`, `maximumHopCountSeen`, `lastActivity`. Published live as `MessageBus.stats`. New structured log events: `packet_delivered_to_destination`, `ack_pending`, `ack_sent`, `ack_received`, `ack_timeout`, `ack_decode_failed`. Existing event schema/behavior unchanged.

### Debug dashboard support

`MeshDashboardSnapshot` (in `MeshStats.swift`) + `MessageBus.dashboard` computed property expose: connected peers (list + count), relay count, average/maximum hop count, pending/acknowledged/timed-out ACK counts, full stats, and last activity. No UI consumes it yet (per scope). To feed the peer *list*, a read-only `connectedPeerIDsPublisher` was added to the `MeshTransport` protocol and `MultipeerTransport` (published on session change / peer loss / stop). This is pure observability — it touches no routing or send path.

### Files modified

- `Mesh/MeshMessage.swift` — `MeshMessage` → `MeshPacket` (+ typealias); optional addressing fields; vocabulary aliases; expanded `MeshMessageType`; `AckPayload`; `relayed(previousHop:)`; `ackTTL`; `isAddressed(to:)`.
- `Mesh/MeshStats.swift` — **new**: `MeshStats`, `MeshDashboardSnapshot`.
- `Mesh/MessageBus.swift` — `@Published stats`, `@Published connectedPeerIDs`; ACK tracking state + `registerPendingAck`/`sendAck`/`processIncomingAck`/`ackTimedOut`; hop/stat accounting in `handleIncoming`/`accept`/`broadcast`/`send`; `dashboard`; deinit cancels pending-ACK timeout tasks.
- `Mesh/MeshTransport.swift` — added `connectedPeerIDsPublisher` requirement.
- `Mesh/MultipeerTransport.swift` — implemented `connectedPeerIDsPublisher` (additive, read-only).
- `Tests/MeshPacketProtocolTests.swift` — **new**, outside the Xcode synchronized group (not compiled into the app; the project has no XCTest target).

### Testing completed

- Generic iOS build: `** BUILD SUCCEEDED **`. Phase 5 code introduced zero new warnings. Four pre-existing `MultipeerTransport` warnings (defer-at-scope-end in resource delegates, dead branch of the auto-accept `true ? :` ternary) and the unrelated AppIntents-metadata warning remain untouched.
- Executable protocol harness (compiles the real Foundation-only model sources): `swiftc Mesh/MeshMessage.swift Mesh/MeshStats.swift Tests/MeshPacketProtocolTests.swift && ./out` → **40/40 assertions PASS**. Covers round-trip serialize/deserialize, backward-compat decode of a legacy byte set, forward-compat (nil optionals omitted), hop-increment-exactly-once, TTL/hop-budget expiry, ACK payload + addressing, packet-type round-trips, stats aggregation.
- Not run: physical multi-device over-the-air test (no devices in this environment) — carried forward as the standing verification gap from Phases 1–4.

### Remaining TODOs / risks

- Physical 2- and 3-device verification of relay + the new ACK round trip is still outstanding (consistent with unresolved P1/P2 statuses).
- ACK matching keys on `destinationPeerID == transport.localPeerID`. Feature layers that originate directed packets must set `destinationPeerID`/`originPeerID` using the transport's stable-ID scheme (`name-<vendorPrefix>`), not the raw `UIDevice.name` the ping demo uses, or ACKs won't match.
- No XCTest target exists; protocol tests are executed via the standalone `swiftc` harness. Wiring a real test target (manual `.pbxproj` surgery on the Xcode-16 synchronized-folder project) was deliberately deferred to avoid destabilizing the build.
- Persistence/encode failures remain best-effort (now counted in `packetsDropped`), still not surfaced to the user.

### Recommended Phase 6 work

Groups — but wait for explicit approval before starting (per the Phase 5 directive). When approved: interpret `groupID` for scoped delivery, add group membership state, and build `groupInvite`/`groupAccept`/`groupLeave` handling on top of this scaffolding. Also candidates: ACK-driven retransmission policy (the deferred half of reliability), and a developer dashboard view backed by `MessageBus.dashboard`. Do not begin production wallet work until `GATE-WALLET-LEGAL` is open.

## Engineering Handoff — Phase 6: Group Management — 2026-07-19

### Scope and result

Application layer on top of the mesh. Transport, the Phase 5 mesh protocol (flood + dedup + TTL + hop counting), the ACK infrastructure, diagnostics, and memory-safety are all preserved and behave exactly as before. Phase 6 adds group membership as a **new layer that rides on the existing bus** — it never touches routing.

**Key architectural property (relay independence):** the bus relays every accepted packet in `MessageBus.handleIncoming` *before and independent of* any group logic, so multi-hop relay is unchanged and works regardless of group membership — exactly as required. `GroupManager` consumes the post-relay `inbox` fan-out and only mutates local state; **non-members relay a group packet (via the bus) and then ignore its payload** (the handler returns early when the packet is not relevant to a group they belong to / an invite addressed to them). Verified by test: a third node relays all group traffic but stores zero group state.

**Decoupling decision:** `GroupManager` depends on a narrow `@MainActor protocol GroupPacketChannel` (`localPeerID`, `groupInbox`, `send`) that `MessageBus` conforms to — not on the concrete bus/transport. This keeps the group layer away from routing entirely and makes it unit-testable against a fake mesh with no MultipeerConnectivity.

### New files

- `Mesh/MeshGroup.swift` — `MeshGroup` replica (`id`, `name`, `adminPeerID`, `members: Set<String>`, `createdAt`) + all seven Codable control payloads + the received-`GroupInvite` view model. `members` is a Set, so **duplicate members are structurally impossible**.
- `Mesh/GroupManager.swift` — `GroupPacketChannel` protocol + `@MainActor final class GroupManager: ObservableObject`.

### Files modified

- `Mesh/MeshMessage.swift` — added packet types `groupDecline`, `groupDelete`, `groupRemove`, `groupSync` (the existing `groupInvite`/`groupAccept`/`groupLeave` are reused). Additive; wire-compatible.
- `Mesh/MessageBus.swift` — declared `GroupPacketChannel` conformance and exposed `localPeerID` + `groupInbox` (a read-only alias of the existing post-relay `inbox`). No routing/send changes.
- `CupertinoCrewApp.swift` — construct one shared `MessageBus` and a `GroupManager(channel: bus)`, inject both as environment objects. No second transport. ContentView/UI unchanged (no group UI this phase — protocol/logic only).
- `Tests/GroupManagerTests.swift` — **new**, outside the synchronized group.

### Operations (all on GroupManager, all return false on an invalid op)

- `createGroup(name:)` — local only, admin = this device, no packet emitted until first invite.
- `inviteMember(_:to:)` — any member may invite. Rejects **self-invite**, **duplicate member**, **duplicate pending invite**, and non-member/unknown-group callers. Emits `groupInvite`.
- `acceptInvite(_:)` / `joinGroup(_:)` (alias) — requires a pending invite; builds/updates the local replica and emits `groupAccept`. Join == accept in this model.
- `declineInvite(_:)` — emits `groupDecline`.
- `leaveGroup(_:)` — member drops its replica, emits `groupLeave`.
- `deleteGroup(_:)` — **admin only**; emits `groupDelete`.
- `removeMember(_:from:)` — **admin only**, cannot target self, member must exist; emits `groupRemove` then a `groupSync`.
- `synchronizeGroup(_:)` — any member broadcasts the full roster snapshot.

### Membership synchronization

Eventually-consistent, admin-authoritative. Each member keeps a `MeshGroup` replica. `groupAccept`/`groupLeave` mutate rosters incrementally; the admin re-broadcasts a `groupSync` (full snapshot) after roster changes so all members converge. Inbound `groupSync`/`groupDelete`/`groupRemove` are honored **only when the packet's stated admin matches the replica's known `adminPeerID`** — a non-admin cannot dissolve a group or evict members. An evicted peer (or one excluded from an authoritative sync) drops its own replica.

### Packet flow (unchanged transport)

Group control packets are ordinary broadcasts: `MeshPacket(type: .group*, groupID: <uuid>, payload: <Codable>)`, `originPeerID = localPeerID`, TTL 300s. They flood + store-and-forward + dedup exactly like any packet (so late joiners can still receive them within the TTL window). They carry no unicast `destinationPeerID`, so they deliberately do **not** engage the Phase 5 ACK path — accept/decline are the application-level acknowledgement of an invite. The Phase 5 ACK infrastructure is untouched and still applies to directed non-group packets.

### Testing completed

- Generic iOS build: `** BUILD SUCCEEDED **`, **zero new warnings** (only the unrelated AppIntents-metadata note and the four pre-existing `MultipeerTransport` warnings remain).
- `Tests/GroupManagerTests.swift` (real `GroupManager` over a fake flood mesh, no transport): **44/44 assertions PASS** — create/invite/accept, non-member ignore, all guard rails (self/duplicate/non-admin/invalid), decline, 3-member sync convergence, admin remove (+ evicted self-drop + peer convergence), leave, admin delete.
- Phase 5 regression: `Tests/MeshPacketProtocolTests.swift` still **40/40 PASS** (ACK, hop-once, TTL, backward/forward compat, stats) — confirms the mesh protocol and ACK infra are unchanged.
- Not run: physical multi-device over-the-air test (no devices here) — standing gap carried from earlier phases.

### Remaining TODOs / risks

- **Trust:** admin authority is enforced by matching `adminPeerID` strings only. The transport is untrusted by design (SRD); a malicious peer could forge a `groupDelete`/`groupRemove` with a spoofed admin ID. Real signing of group control packets is deferred — required before any production use.
- **Admin departure:** an admin may `leaveGroup` (leaving members with a stale admin field) rather than being forced to `deleteGroup`. No admin succession is implemented. Decide the policy in a later phase.
- **Replica bootstrap:** on accept, a joiner's replica starts as `{admin, self}` until the admin's `groupSync` arrives; during a partition it may be briefly incomplete (converges on reconnect via store-and-forward). Acceptable for the eventually-consistent model; document for UI.
- No XCTest target still (protocol/group tests run via the standalone `swiftc` harness); no group UI (logic-only phase).
- `pendingInvitees` is per-device bookkeeping for dup-invite suppression and is not synced; two members inviting the same peer simultaneously can both emit an invite (harmless — the invitee dedups, and a second accept is a Set no-op).

### Recommended Phase 7 work

Group-scoped messaging UI + `groupID`-filtered display on top of this membership layer; sign group control packets (close the trust TODO); ACK-driven retransmission (the deferred half of Phase 5 reliability). Do not begin production wallet work until `GATE-WALLET-LEGAL` is open.

## Engineering Handoff — Developer Group Testing UI — 2026-07-19

### Scope and result

UI-only. A developer testing screen for the existing Phase 6 `GroupManager` was added. No transport, routing, ACK, or mesh-protocol code was modified — nothing under `Mesh/` changed except that the UI reads its published state. The screen contains **no business logic**: every action calls an existing `GroupManager` / `MessageBus` API and every value is bound to existing published state. Not a shipping/user-facing screen.

### Files

- `GroupTestingView.swift` — **new**. `GroupTestingView` (identity, connected peers, pending invites, create, group list) + `GroupDetailView` (member roster, invite connected peer, leave, admin delete/remove). Both take `MessageBus` and `GroupManager` as `@EnvironmentObject` (already injected at the app root in Phase 6).
- `ContentView.swift` — added a single `Section("Developer")` with a `NavigationLink` to `GroupTestingView`. The existing diagnostics screen is otherwise unchanged (no redesign).

### What it exposes / does

- Displays: **Local Peer ID** (`groups.localPeerID`), **Connected Peers** (`bus.connectedPeerIDs` + `bus.peerCount`), **My Groups** with admin badge, **Current Group** (the `GroupDetailView` you drill into, looked up live so it reflects membership changes and empties on delete/eviction), **Pending Invitations** (`groups.receivedInvites`).
- Actions (all call existing APIs): Create (`createGroup`), Invite a connected peer (`inviteMember`), Accept/Decline (`acceptInvite`/`declineInvite`), Leave (`leaveGroup`), Delete — admin (`deleteGroup`), Remove Member — admin (`removeMember`). Admin-only buttons render only when `group.isAdmin(localPeerID)`.
- Each guarded op's Bool result is surfaced in a "Last action" row (`ok` / `rejected`) so a tester can see when a guard (self-invite, duplicate, non-admin, etc.) fires.

### Known limitation surfaced (NOT fixed — backend, out of this phase's scope)

The transport's identity scheme is inconsistent: a device's own `transport.localPeerID` is `displayName + "-" + vendorPrefix`, but peers are listed to each other via `connectedPeerIDs` = `displayName` only (no suffix). So "Invite connected peer" sends an invite keyed by the bare display name, which will **not** match that invitee's own `localPeerID` — cross-device membership convergence can therefore fail even though every UI action executes and every guard behaves correctly. This is a pre-existing backend ID-scheme issue (already flagged in the Phase 5 handoff's addressing TODO), not a UI defect. Fixing it means unifying the transport's self-ID and peer-ID representation — a transport change, explicitly out of scope here. Recommended as the first item of the next backend phase.

### Testing performed

- Generic iOS build: `** BUILD SUCCEEDED **`, **zero new warnings** (only the unrelated AppIntents note + the four pre-existing `MultipeerTransport` warnings remain).
- Backend regression (the APIs the UI drives): `GroupManagerTests` **44/44 PASS**, `MeshPacketProtocolTests` **40/40 PASS** — mesh protocol, ACK infra, and group logic all unchanged.
- Not performed: driving the SwiftUI screen over the air. This project is real-device-only (no simulator, per the Decisions Log) and no physical devices are available in this environment, so the UI could not be exercised live. The screen binds exclusively to already-tested APIs; on-device click-through of the group flows remains an outstanding manual verification step (same standing device-test gap as prior phases).

### Remaining TODOs

- Manual on-device walkthrough of the testing UI across 2–3 phones.
- Unify the transport peer-ID scheme (see limitation above) before group membership can converge across real devices.
- All prior-phase TODOs still stand (group control-packet signing, admin succession, no XCTest target, no user-facing group UI).

## Engineering Handoff — Bugfix: Group Invitation Lifecycle (identity mismatch) — 2026-07-19

### Symptom

A creates a group and invites B. B receives the GROUP_INVITE packet (visible in the Received section) but it never appears in Pending Invitations and B gets no Accept/Decline option.

### Root cause

The transport used two *different* identity representations for the same device:
- `MultipeerTransport.localPeerID` was `MCPeerID.displayName + "-" + <vendorPrefix>` (e.g. `"Bob-e5f6g7h8"`). This is the value `MessageBus.localPeerID` → `GroupManager.localPeerID` exposes, i.e. how a device identifies *itself* (group admin/member ID, invite-target check).
- Every place a device is referred to by *others* uses `stableID(for:) == MCPeerID.displayName` (e.g. `"Bob"`): `connectedPeerIDs`, `peerConnected`, and the `from` on received packets.

The vendor suffix is device-local (`identifierForVendor`) and can never be reproduced by a remote peer, so a device's self-ID never equaled the ID others addressed it by. Concretely: the testing UI invites the peer shown in `connectedPeerIDs` (`"Bob"`), so the packet's `invitedPeerID == "Bob"`; on B, `GroupManager.handleInvite` runs `guard p.invitedPeerID == localPeerID` → `"Bob" == "Bob-e5f6g7h8"` → false → early return. The invite is silently dropped; `receivedInvites` never mutates; SwiftUI has nothing to show. Transport/decoding/subscription/@MainActor/@Published were all fine — the lifecycle died at the identity comparison.

This was masked by the Phase 6 unit tests, which used self-consistent IDs (`"A"`/`"B"`/`"C"`) and therefore never exercised the mismatch. `MessageBus.localPeerID` (line 56) was the sole consumer of the suffix.

The reported "Device A marks the invitation Rejected": no such path exists in this codebase — `GroupManager.emit` sets no `destinationPeerID`, so group invites never register a pending ACK, so there is no ACK timeout and no auto-reject. Sender state changes only on an explicit inbound `groupAccept`/`groupDecline`. Requirement "sender must never mark accepted/rejected without an explicit packet" was already satisfied and remains so.

### Fix implemented

`Mesh/MultipeerTransport.swift` — `localPeerID` is now `peerID.displayName` (the vendor suffix removed), making the local self-ID identical to the peer-visible `stableID`. One line of behavior; no change to routing, relay, dedup, ACK, or the mesh protocol — those already keyed on `displayName` (`stableID`) everywhere. If anything this also makes the Phase 5 ACK `destinationPeerID == localPeerID` match correct for directed packets. After the fix: A invites `"Bob"`, B's `localPeerID == "Bob"`, the guard passes, the invite is stored, `@Published receivedInvites` updates, SwiftUI shows it, Accept/Decline emit `groupAccept`/`groupDecline`, and A converges — the full lifecycle.

### Files modified

- `Mesh/MultipeerTransport.swift` — `localPeerID` set to bare `displayName` (+ explanatory comment). No UI was patched (per instruction).
- `Tests/GroupManagerTests.swift` — added a root-cause regression: an invite addressed to an ID that is not the invitee's `localPeerID` is NOT stored (bug repro), and a correctly-addressed invite IS stored. Locks the identity invariant.

### Verification performed

- Generic iOS build: `** BUILD SUCCEEDED **`, no new warnings (only the unrelated AppIntents note + four pre-existing `MultipeerTransport` warnings).
- `GroupManagerTests`: **48/48 PASS** (44 prior + 4 new regression assertions), including "mismatched-ID invite is NOT stored" and "correctly-addressed invite IS stored".
- `MeshPacketProtocolTests`: **40/40 PASS** — mesh protocol, ACK, hop, TTL, backward/forward compat unchanged by the identity fix.
- Not performed: two-physical-device confirmation (invite appears immediately, accept/decline, no auto-reject, membership sync). No devices are available in this environment (real-device-only project). The fix is proven at the logic level (guard now matches) and by the regression test; on-device confirmation across 2 phones remains the one outstanding manual step.

### Remaining TODOs

- On-device 2-phone confirmation of the invite → accept/decline → membership-sync flow.
- Duplicate `displayName`s across devices now collide on identity (Multipeer names are `UIDevice.name`); acceptable for the current test fleet (distinct names), but a durable unique-yet-shareable peer ID (exchanged via discovery info, not a local-only suffix) is the proper long-term fix.
- All prior-phase TODOs still stand (group control-packet signing, admin succession, no XCTest target).

## Engineering Handoff — Bugfix: connected peer missing from "Invite Connected Peer" — 2026-07-19

### Symptom

A peer is connected (shows in the peer count) but does not appear in a group's "Invite Connected Peer" list, so it cannot be invited.

### Root cause

Duplicate-identity collision introduced by the previous fix. `peerCount` and `connectedPeerIDs` are both published from `session.connectedPeers` in the same block (`MultipeerTransport` didChange, lines ~255–256), so the list is never empty while the count is positive — the peer *is* in `connectedPeerIDs`. The invite list filters `bus.connectedPeerIDs.filter { !group.contains($0) }`. The prior fix set identity to the **bare `UIDevice.name`**, so two devices sharing a name (e.g. several un-renamed "iPhone"s) resolve to the *same* identity string. The group admin's own member ID then equals the connected peer's ID, `group.contains(peer)` is true, and the peer is filtered out as "self." (Membership would also silently misbehave.)

### Fix implemented

`Mesh/MultipeerTransport.swift` — the uniqueness token (`identifierForVendor` prefix, stable per install) is now baked into the **`MCPeerID.displayName` itself** (`"\(UIDevice.name)#\(token)"`), not appended only to `localPeerID`. Because the displayName is what Multipeer propagates to peers, `stableID(for:)` (== remote `displayName`), `connectedPeerIDs`, and each device's own `localPeerID` are now the **same unique-and-shared** string. This satisfies both requirements simultaneously: unique per device (no collision → connected non-member peers show and can be invited) and shareable (the invite's `invitedPeerID` still equals the invitee's `localPeerID`, so the Phase-6 invite lifecycle fix from the previous handoff keeps working). This supersedes the previous handoff's bare-displayName choice and closes the "durable unique-yet-shareable peer ID" TODO.

### Files modified

- `Mesh/MultipeerTransport.swift` — `MCPeerID` constructed with `"<name>#<vendorToken>"`; `localPeerID` = that displayName. No routing/ACK/mesh-protocol logic changed. No UI patched.

### Verification performed

- Generic iOS build: `** BUILD SUCCEEDED **`, no new warnings (only the standing pre-existing ones).
- `GroupManagerTests` **48/48** and `MeshPacketProtocolTests` **40/40** remain green (transport identity is not exercised by the harnesses; group/protocol logic unchanged).
- Not performed: 2-physical-device confirmation that the connected peer now appears in the invite list and an invite round-trips (no devices in this environment). Proven at the logic level: distinct devices now yield distinct IDs, so the `!group.contains($0)` filter no longer hides a real peer, while self-ID == peer-visible ID keeps the invite check matching.

### Remaining TODOs

- On-device 2-phone confirmation (peer shows in invite list → invite → accept/decline → membership sync).
- A truly persistent identity across app reinstalls would need a stored token rather than `identifierForVendor` (which resets on reinstall); acceptable for now.
- All prior-phase TODOs still stand.
