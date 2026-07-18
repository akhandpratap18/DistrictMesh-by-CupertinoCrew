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
