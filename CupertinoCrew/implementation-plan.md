# District Offline Mesh Add-on — Phased Implementation Plan

**Audience:** workhorse engineering agents and project stakeholders. Read this together with `agents.md` (task tracking) and `srd.md` (requirements). All three documents use the same feature names, IDs, and phase numbers.

## Feature & Component Naming (used consistently across all documents)

| ID | Name | Summary |
|----|------|---------|
| F0 | Mesh Core | Shared P2P infrastructure: transport layer, peer discovery, store-and-forward message bus, pre-event content caching, hybrid re-sync. Not user-facing; prerequisite for everything else. |
| F1 | Offline Wallet | Pre-loaded secure vault, signed voucher exchange with vendor iPads, data-mule ledger reconciliation. |
| F2 | Lost Friend Compass | Pairwise radio-based ranging rendered as directional arrow + distance. |
| F3 | Excess Harvest Pipeline | Vendor "Surplus Alert" broadcasts for end-of-event food redistribution. |
| F4 | Emergency Overrides ("God Mode") | Organizer-issued, store-and-forward, venue-wide high-priority alerts. |

## Sequencing Rationale

The four user-facing features all sit on top of F0 Mesh Core, so F0 is built first and validated hard before any feature work. Among the features, sequencing is by technical risk and dependency, not by the order they appear in the product brief:

1. **F4 and F3 come first** among features. Both are one-to-many broadcast patterns over store-and-forward — the simplest possible consumers of the mesh — and building them doubles as a real-world validation of mesh propagation (which F4 needs proven anyway before anyone dares call it "emergency-grade").
2. **F2 next.** It introduces a different technical problem (pairwise ranging/direction, not messaging) with its own hardware-capability spike, but has no dependency on wallet or ledger work.
3. **F1 last.** Highest technical risk (cryptographic vouchers, double-spend, reconciliation), a second client platform (vendor iPad), and — critically — it is **gated on legal/compliance and App Store policy review**, which starts in Phase 0 but may not resolve until later. Scheduling it last means legal review has maximum runway before it can block engineering.

## Transport Decision (settled)

The transport is decided: **Apple Multipeer Connectivity (native iOS)**. No third-party mesh SDK is used, and there is no separate fallback transport. This resolves former Open Question OQ-1, and GATE-TRANSPORT is **OPEN** (see `agents.md`). Phase 0 still characterizes Multipeer's practical limits before feature work commits (task P0-01), but this is validation of the chosen stack, not a selection exercise. Feature requirements remain written against an internal transport abstraction (see SRD System Overview) so the codebase stays decoupled from Multipeer specifics, but no second transport is planned.

---

## Phase 0 — Spikes, Decisions & Compliance Kickoff

**Goal:** Retire the biggest unknowns before committing to architecture, and start the long-lead legal/compliance clocks.

**Features touched:** F0 (directly), F1/F2/F4 (via spikes and reviews).

**Dependencies:** None. This is the starting phase.

**Work in this phase:**

- **Transport characterization spike.** Multipeer Connectivity is already the chosen transport; this spike measures its practical limits before feature work commits: peer/session count ceilings at venue scale (feeds OQ-7), background-mode behavior on iOS (feeds OQ-6), range in dense human crowds (bodies attenuate 2.4 GHz badly), and reconnection behavior. Deliverable: a written characterization report with numbers, plus confirmation that no capability gap forces reconsidering the single-transport approach.
- **Crowd propagation spike.** Field test with a fleet of test devices (target: 20+ phones in a genuinely crowded environment) measuring hop latency, delivery rate, and dead-zone formation. This directly informs whether F4 can ever be positioned as safety-relevant (feeds OQ-5).
- **Battery drain spike.** Measure battery cost of continuous advertising/scanning/connected mesh participation over a 6–8 hour "event day" profile. Establish the duty-cycling budget the Mesh Core must hit (feeds NFR-BAT requirements in the SRD).
- **Ranging feasibility spike (F2).** Determine what direction+distance quality is achievable: Ultra Wideband / Nearby Interaction on U1/U2-chip devices vs. Bluetooth RSSI-only estimation on older devices. Deliverable: a capability matrix by device generation and a recommendation on minimum supported experience.
- **Legal/compliance kickoff (F1 gate).** Brief legal counsel on the offline voucher payment model. Questions to put to them are enumerated in SRD Open Questions OQ-2 and OQ-3 (payment services regulation, stored-value/e-money classification, Apple in-app purchase and payment policy exposure). **No F1 implementation work may start until written sign-off exists.**
- **Privacy review kickoff (F2 gate).** Brief privacy/legal on continuous peer ranging: consent model, opt-out, retention (SRD OQ-4).
- **Safety-positioning review kickoff (F4 gate).** Decide with legal/marketing whether F4 may be described as an emergency system or must be positioned as supplementary to official channels (SRD OQ-5). Engineering on F4 can proceed in parallel, but launch copy and organizer contracts are blocked on this.

**Exit criteria (a workhorse must have finished before Phase 1 starts):**
- Transport characterization report (Multipeer limits) written and referenced in `agents.md`.
- Crowd, battery, and ranging spike reports written with numbers, not impressions.
- All three legal/privacy reviews formally opened with named owners and expected response dates recorded in `agents.md` (they need not be *resolved* — except that F1's must resolve before Phase 4).

**Compliance flag:** This phase contains the *start* of three non-engineering gates. They block later phases as noted, not Phase 1.

---

## Phase 1 — F0 Mesh Core (MVP Infrastructure)

**Goal:** A working, testable P2P foundation that every feature will consume. No user-visible features yet beyond a hidden diagnostics screen.

**Features touched:** F0 only.

**Dependencies:** Phase 0 transport characterization spike (P0-01). Transport itself is already decided (Multipeer Connectivity).

**Work in this phase (described functionally — implementation details are the workhorses' job):**

- **Transport abstraction.** A single internal interface for peer discovery, session management, and message send/receive, so Multipeer Connectivity sits behind one seam and its specifics don't leak into feature code. This is for testability and isolation, not to support a second transport — none is planned. Described in SRD System Overview.
- **Store-and-forward message bus.** Messages carry: unique ID, type, priority class, origin, timestamp, hop count / TTL, and payload. Devices persist undelivered messages, deduplicate by ID, re-broadcast per priority policy, and expire per TTL. Priority classes must exist from day one because F4 depends on preemption (emergency traffic beats everything).
- **Pre-event caching pipeline.** Over cellular, before entry: venue map, vendor menus, event schedule, organizer public keys (needed later by F1 and F4 for signature verification). Cache is versioned and integrity-checked.
- **Hybrid re-sync framework.** When any connectivity reappears, queued outbound data uploads and cache updates download. Built generically now; F1's data-mule behavior in Phase 4 is a specialization of this.
- **Diagnostics & telemetry harness.** Internal screen + logging showing peers, message queue, hop counts, delivery confirmations. This is the test instrument for every later phase; treat it as a first-class deliverable.

**Exit criteria:**
- In a physical multi-device test (minimum 10 devices, airplane-mode cellular), a message injected on one device reaches ≥95% of devices within the latency budget set from the Phase 0 crowd spike.
- Store-and-forward demonstrated: a device offline during broadcast receives the message after rejoining.
- Pre-event cache demonstrated end-to-end (fetch on cellular → verify → available offline).
- Battery consumption over a 4-hour idle-mesh test is within the Phase 0 duty-cycle budget.
- Diagnostics screen usable by a non-author agent to verify all of the above.

---

## Phase 2 — Broadcast Features: F4 Emergency Overrides + F3 Excess Harvest

**Goal:** Ship the two broadcast-pattern features, using them to battle-harden mesh propagation. F4 is built first within the phase because its requirements (priority preemption, signing, delivery tracking) are a superset of F3's.

**Features touched:** F4, F3; hardening of F0.

**Dependencies:** Phase 1 complete. F4 *engineering* is not blocked by OQ-5, but F4 *launch positioning* is.

**Work in this phase:**

- **F4 organizer authoring path.** A venue-managed origination flow (organizer device/console) that creates signed alert messages: type (weather, missing child, schedule change, evacuation), severity, body text, validity window. Signed with organizer keys distributed via the Phase 1 cache; unsigned or badly signed alerts are rejected and never displayed.
- **F4 attendee experience.** Full-screen high-priority alert presentation, distinct sound/haptics per severity, acknowledgment stored locally, alert history. Alerts propagate at top priority class and preempt all other mesh traffic.
- **F4 delivery observability.** Best-effort delivery/acknowledgment reporting flowing back over the mesh and via re-sync, so organizers can see coverage estimates. This is also the data that answers "can this ever be safety-grade?" (OQ-5).
- **F3 vendor Surplus Alert.** Vendor-originated broadcast: items, quantity, price/free flag, stall location, expiry time. Propagates at a normal (sub-emergency) priority class.
- **F3 attendee/staff experience.** Role-aware surfacing (staff/volunteers prioritized), claim intent flow (claim messages route back toward the vendor over the mesh; vendor confirms; over-claiming handled by first-confirmed-wins with graceful "already claimed" messaging), auto-expiry of stale alerts.
- **F0 hardening from real usage:** loop suppression, rebroadcast storm damping, TTL tuning — whatever the field tests expose.

**Exit criteria:**
- Field test: an F4 alert issued at one edge of a ≥20-device dispersed test reaches ≥99% of devices, and the diagnostics harness proves preemption over concurrent F3 traffic.
- F3 end-to-end demo: vendor broadcasts, attendee claims, vendor confirms, alert expires — all offline.
- Signature verification demonstrably rejects tampered/unsigned F4 alerts.
- OQ-5 status recorded: if still open, F4 remains dark-launchable but a launch blocker entry exists in `agents.md`.

---

## Phase 3 — F2 Lost Friend Compass

**Goal:** Pairwise finding: two consenting attendees see a live arrow and distance to each other with no GPS or network.

**Features touched:** F2; minor F0 additions (pairing handshake messages).

**Dependencies:** Phase 1 (mesh for pairing/handshake). Phase 0 ranging spike decides the technical approach. **Gate:** privacy review (OQ-4) must be resolved before this feature ships to beta; engineering may proceed against the draft consent model.

**Work in this phase:**

- **Pairing & consent flow.** Mutual, explicit, revocable-by-either-side pairing between exactly two devices, established over the mesh. Consent state and UX per the privacy review's requirements (SRD data-privacy NFRs).
- **Ranging engine.** Per the Phase 0 capability matrix: precise direction+distance on UWB-capable device pairs; degraded distance-band experience ("warmer/colder" + approximate meters) on RSSI-only pairs; honest UI about which mode is active. Smoothing/filtering so the arrow is steady in a moving crowd.
- **Battery discipline.** Ranging runs only during an active finding session; sessions time-bound with re-confirmation; duty-cycled per the Phase 0 battery budget.
- **No retention.** Proximity/direction data is ephemeral by requirement (see SRD); verify nothing is logged or synced.

**Exit criteria:**
- Two-device field test in a dense crowd: users physically find each other using only the compass, in both UWB and degraded modes.
- Battery cost of a 10-minute finding session measured and within budget.
- Privacy review sign-off recorded, or a launch-blocker entry in `agents.md`.
- Verified (by inspection and by re-sync traffic audit) that no ranging data persists or uploads.

---

## Phase 4 — F1 Offline Wallet & Payments

**Goal:** The full offline commerce loop: pre-load → vault lock → signed voucher purchase at a vendor iPad → data-mule reconciliation → post-event ledger settlement.

**Features touched:** F1; F0 re-sync specialization (data mule).

**Dependencies:** Phases 1–2 (mesh maturity, signing infrastructure patterns from F4, vendor-side patterns from F3). **Hard gate: legal/compliance and App Store policy sign-off (OQ-2, OQ-3) must be complete and recorded before any task in this phase starts.** If sign-off imposes a changed model (e.g., processor-mediated settlement, closed-loop credit instead of cash value), this phase's scope is re-planned first.

**Work in this phase:**

- **Vault load & lock.** Pre-event, over cellular: user loads funds via the existing (online) payment path; a locked local balance with associated signing credentials is provisioned to the device. Vault contents protected by device secure storage; the SRD defines tamper-resistance requirements.
- **Voucher purchase protocol.** Attendee ↔ vendor iPad exchange over short-range radio: vendor presents a charge request; attendee approves; a signed, single-use, uniquely-identified voucher transfers; vendor device verifies signature and marks the voucher accepted; attendee's local balance decrements. Double-spend defenses per SRD security NFRs (single-use IDs, monotonic counters/balance attestation, vendor-side duplicate rejection) — the residual pre-reconciliation fraud window is a *documented, legally-reviewed* risk, not an engineering afterthought.
- **Vendor iPad experience.** Charge creation, acceptance confirmation, offline sales log, end-of-day summary.
- **Data mule.** Any participating device that gains connectivity uploads its own and relayed voucher records (encrypted, origin-anonymous with respect to the mule) to the reconciliation service. Mule behavior is silent, rate-limited, and battery/data-budgeted.
- **Reconciliation & dispute pipeline (server-side + product policy).** Ledger settlement rules, conflict detection (double-spend, balance mismatch), and the dispute process per the fraud/dispute policy that legal review produces (OQ-3).

**Exit criteria:**
- End-to-end offline demo: load on cellular → airplane mode → three purchases at two vendor iPads → one device regains signal → central ledger reconciles all vouchers correctly.
- Adversarial test suite passes: replayed voucher rejected, tampered voucher rejected, forced double-spend detected at reconciliation and flagged per policy.
- Vendor day-in-the-life test with an actual vendor-role user completing 20+ transactions.
- Legal sign-off reference recorded against every shipped behavior it conditions.

---

## Phase 5 — Hardening, Scale Trial & Launch Readiness

**Goal:** Prove the whole system at realistic scale and close every launch gate.

**Features touched:** All.

**Dependencies:** Phases 1–4 complete; all open legal/privacy/positioning gates resolved (OQ-2 through OQ-5).

**Work in this phase:**

- **Scale field trial** at a real mid-size event (target: hundreds of devices) exercising all four features together; measure against every NFR in the SRD (delivery rates, latencies, battery, reconciliation accuracy).
- **Failure-mode drills:** dead-zone formation, mass simultaneous join/leave (gates opening), vendor iPad crash mid-transaction, malicious-message fuzzing at the mesh layer.
- **Performance & battery tuning** to final NFR numbers.
- **App Store submission dry run** with the wallet flow documented for review, per whatever the OQ-2 outcome requires.
- **Operational readiness:** organizer onboarding materials for F4, vendor onboarding for F1/F3, support/dispute runbooks, incident process for emergency-alert misuse.

**Exit criteria (launch):**
- All SRD P0 requirements verified at the scale trial and recorded in `agents.md`.
- Zero open legal/compliance blockers.
- App Store approval obtained.
- Go/no-go review with stakeholders signed.

---

## Cross-Phase Risk Register (surface, don't solve — owners TBD)

| Risk | Type | Blocks | Tracked as |
|------|------|--------|-----------|
| Offline vouchers = moving real money outside a live processor; payment-services regulation; Apple review policy | Legal / App Store | Phase 4 start | OQ-2 |
| Voucher replay/double-spend window pre-reconciliation; fraud & dispute process | Legal + security | Phase 4 start (policy), Phase 4 exit (tests) | OQ-3 |
| Continuous P2P ranging privacy: consent, opt-out, retention | Privacy/legal | F2 beta ship | OQ-4 |
| F4 as safety-critical: propagation gaps, dead zones; supplementary-only positioning? | Legal/marketing + technical | F4 launch positioning | OQ-5 |
| iOS background execution limits may kill mesh participation when the app is backgrounded/locked — could undermine F4 reach and F1 data-mule silently | Technical (platform) | Phase 1 design; re-verify each iOS release | OQ-6 |
| Multipeer Connectivity practical peer-count ceilings at venue scale (thousands of devices) | Technical | Phase 0 spike must size this | OQ-7 |
| Battery drain from all-day mesh participation may cause users to disable the feature, collapsing the mesh for everyone (participation death spiral) | Technical/product | NFR budgets; Phase 5 trial | OQ-8 |
| Vendor iPad availability/enrollment and key distribution logistics | Operational | Phase 4/5 | OQ-9 |
| Clock skew across offline devices affects voucher timestamps, alert validity windows, and surplus expiry | Technical | Phase 1 design | OQ-10 |
