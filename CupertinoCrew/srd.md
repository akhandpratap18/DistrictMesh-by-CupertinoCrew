# Software Requirements Document (SRD)
## District Offline Mesh Add-on

**Companion documents:** `implementation-plan.md` (phasing), `agents.md` (task tracking). Feature IDs (F0–F4), open questions (OQ-*), and terminology are shared across all three.

---

## 1. Purpose & Scope

**Purpose.** Define the requirements for an offline-first add-on to the existing District iOS app, enabling core event functionality — payments, friend-finding, surplus-food redistribution, and emergency alerts — at large venues where cellular networks are congested to the point of failure.

**In scope:**
- F0 Mesh Core: P2P transport, store-and-forward messaging, pre-event caching, hybrid re-sync (shared infrastructure).
- F1 Offline Wallet: pre-loaded vault, signed voucher purchases, data-mule reconciliation.
- F2 Lost Friend Compass: pairwise radio-based direction and distance finding.
- F3 Excess Harvest Pipeline: vendor surplus broadcasts and claiming.
- F4 Emergency Overrides ("God Mode"): organizer-issued, mesh-propagated, high-priority alerts.
- Vendor-facing iPad experience for F1 and F3.
- Server-side reconciliation for the F1 ledger.

**Out of scope:** Android support; any change to District's existing online functionality beyond integration points (funding the vault, downloading caches); venue hardware (beacons, routers); replacing official venue emergency systems (see OQ-5).

## 2. System Overview

District today is a conventional client-server iOS app. This add-on introduces a second operating mode with a **P2P decentralized topology**: while inside a venue with no usable connectivity, devices form an ad-hoc mesh over short-range radio and communicate directly, phone to phone.

Conceptual pillars (no implementation detail here — see the plan's Phase 1 description for build guidance):

1. **Mesh transport layer.** Devices discover nearby peers and exchange messages over short-range radio using **Apple Multipeer Connectivity** (native iOS). No third-party mesh SDK and no separate fallback transport are used (decided; OQ-1 resolved). Feature requirements below remain transport-agnostic and interact only with an internal transport abstraction, for isolation and testability rather than to support an alternate transport.
2. **Store-and-forward messaging.** Messages are addressed, uniquely identified, prioritized, time-bounded, and persisted; devices carry and re-broadcast messages so content hops across the crowd and reaches devices that were unreachable at send time. Emergency traffic (F4) preempts all other classes.
3. **Pre-event local caching.** Before entering the venue, over cellular, the app pre-fetches venue map, vendor menus, schedule, and organizer public keys, so the offline experience starts fully provisioned and signed content can be verified offline.
4. **Hybrid re-sync.** Whenever any device regains connectivity (venue edge, vendor uplink), queued outbound data — its own and, for F1, relayed voucher records ("data mule") — uploads to central services, and cache updates download. The system converges: offline divergence is temporary and reconciled by defined rules (§4.1, §5.7).

Trust model at a glance: organizers and vendors hold signing credentials; attendee devices verify signatures locally against pre-cached keys; attendee wallet operations are themselves signed so vendors and the central ledger can verify them. The mesh itself is untrusted transport — any device may relay any message, and no relayed message is believed without verification.

## 3. Functional Requirements

Requirements are testable "the system shall" statements. Priority: **P0** (cannot ship without), **P1** (fast follow), noted inline.

### 3.0 F0 Mesh Core

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-MESH-01 | The system shall discover and connect to nearby District devices without any internet or cellular connectivity. | P0 |
| FR-MESH-02 | The system shall deliver messages between devices that are not in direct radio range by relaying via intermediate devices (multi-hop). | P0 |
| FR-MESH-03 | The system shall persist undelivered messages locally and deliver them to peers that join the mesh later, within each message's validity window (store-and-forward). | P0 |
| FR-MESH-04 | The system shall deduplicate messages by unique identifier so no message is presented to a user or processed by a feature more than once. | P0 |
| FR-MESH-05 | The system shall support at least three message priority classes, with emergency-class traffic (F4) transmitted in preference to all other traffic. | P0 |
| FR-MESH-06 | The system shall expire and cease relaying messages whose validity window or hop limit is exceeded. | P0 |
| FR-MESH-07 | The system shall pre-fetch and locally store venue map, vendor menus, event schedule, and organizer public keys when connectivity is available before the event, and shall verify the integrity of that cache before use. | P0 |
| FR-MESH-08 | The system shall make all pre-cached content fully usable with zero connectivity. | P0 |
| FR-MESH-09 | The system shall, upon regaining any connectivity, upload queued outbound data and download cache updates without user action. | P0 |
| FR-MESH-10 | The system shall provide an internal diagnostics view showing current peers, message queue state, and delivery statistics (internal builds only). | P0 |

### 3.1 F1 Offline Wallet & Payments

*All F1 requirements are conditional on GATE-WALLET-LEGAL (OQ-2, OQ-3); legal review may alter or strike individual requirements.*

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-WAL-01 | The system shall allow a user to load funds into a local vault only while online, via District's existing payment path, before venue entry. | P0 |
| FR-WAL-02 | The system shall store the vault balance and signing credentials in device secure storage such that the balance cannot be modified except by the defined purchase and reconciliation flows. | P0 |
| FR-WAL-03 | The system shall allow a vendor iPad to present a charge request (amount, vendor identity, line items) to an attendee device over short-range radio with no connectivity. | P0 |
| FR-WAL-04 | The system shall require explicit attendee approval on the attendee's device before any voucher is issued. | P0 |
| FR-WAL-05 | The system shall, upon approval, generate a cryptographically signed, single-use voucher with a globally unique identifier, transfer it to the vendor device, and decrement the local balance atomically with issuance. | P0 |
| FR-WAL-06 | The vendor device shall verify each voucher's signature and uniqueness locally before confirming the sale, and shall reject vouchers that fail verification or duplicate a previously accepted voucher identifier. | P0 |
| FR-WAL-07 | The system shall refuse to issue a voucher exceeding the current local balance. | P0 |
| FR-WAL-08 | The system shall queue all issued and accepted voucher records for upload, and shall opportunistically relay encrypted voucher records from nearby devices ("data mule") for upload when any participating device regains connectivity. | P0 |
| FR-WAL-09 | Data-mule relay shall be silent (no user interaction), shall not expose voucher contents to the relaying device, and shall respect the battery and data budgets in §4.2. | P0 |
| FR-WAL-10 | The central ledger shall reconcile uploaded vouchers against vault loads, detect conflicts (including double-spend and balance mismatch), and route conflicts into the dispute process defined under OQ-3. | P0 |
| FR-WAL-11 | The system shall display the attendee's local balance and offline transaction history at all times, clearly marked as "pending reconciliation" until centrally settled. | P0 |
| FR-WAL-12 | The system shall return any unspent, reconciled balance to the user through the defined refund path after the event. | P0 |
| FR-WAL-13 | The vendor device shall provide an offline sales log and end-of-day summary. | P1 |

### 3.2 F2 Lost Friend Compass

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-CMP-01 | The system shall establish a finding session only after both users explicitly consent, via a mutual pairing exchanged over the mesh. | P0 |
| FR-CMP-02 | Either user shall be able to terminate a finding session at any time, immediately stopping ranging on both devices. | P0 |
| FR-CMP-03 | During an active session between capable device pairs, the system shall display a live directional arrow and estimated distance in meters to the paired device, using direct radio signal measurement and no GPS or network positioning. | P0 |
| FR-CMP-04 | On device pairs lacking precise-ranging hardware, the system shall provide a degraded distance-band experience and shall clearly indicate that degraded mode is active. | P0 |
| FR-CMP-05 | The system shall update direction/distance frequently enough for a walking user to follow the arrow in a dense crowd (target refresh defined in §4.3). | P0 |
| FR-CMP-06 | Finding sessions shall be time-limited, requiring re-confirmation to continue beyond the limit. | P0 |
| FR-CMP-07 | The system shall not persist, log, or transmit ranging data (direction, distance, proximity history) beyond the live session, on-device or via re-sync. | P0 |
| FR-CMP-08 | The system shall not make any user discoverable for pairing unless that user has enabled discoverability, and shall provide a global opt-out. | P0 |

### 3.3 F3 Excess Harvest Pipeline

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-EHP-01 | The system shall allow an authenticated vendor device to broadcast a Surplus Alert (items, quantities, price or free flag, stall location, expiry time) over the mesh with no connectivity. | P0 |
| FR-EHP-02 | The system shall surface Surplus Alerts to staff and registered volunteers with priority over general attendees. | P0 |
| FR-EHP-03 | The system shall allow a recipient to send a claim over the mesh, and the vendor device to confirm or decline claims; confirmations are first-confirmed-wins per quantity. | P0 |
| FR-EHP-04 | The system shall inform a claimant when an item is already fully claimed. | P0 |
| FR-EHP-05 | The system shall stop displaying and relaying a Surplus Alert at its expiry time. | P0 |
| FR-EHP-06 | Surplus Alerts shall propagate at a priority class below emergency (F4) traffic. | P0 |
| FR-EHP-07 | The system shall record surplus outcomes (claimed / expired) for post-event reporting once reconciled. | P1 |

### 3.4 F4 Emergency Overrides ("God Mode")

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-EMG-01 | The system shall allow only credentialed organizer identities to originate emergency alerts; alerts shall be cryptographically signed at origination. | P0 |
| FR-EMG-02 | Attendee devices shall verify alert signatures against pre-cached organizer keys and shall never display an alert that fails verification. | P0 |
| FR-EMG-03 | Emergency alerts shall support at minimum these types: weather hazard, missing child, schedule change, evacuation — each with a severity level and validity window. | P0 |
| FR-EMG-04 | Emergency alerts shall propagate at the highest priority class, preempting all other mesh traffic. | P0 |
| FR-EMG-05 | Receiving devices shall present emergency alerts as high-priority full-screen notifications with severity-appropriate sound and haptics, and shall retain them in an accessible alert history. | P0 |
| FR-EMG-06 | Devices shall continue relaying an alert for its full validity window so late joiners and dead-zone exits receive it (store-and-forward). | P0 |
| FR-EMG-07 | The system shall collect best-effort delivery/acknowledgment data and report estimated coverage to the organizer over the mesh and via re-sync. | P0 |
| FR-EMG-08 | The system shall allow an organizer to issue a signed cancellation/all-clear that supersedes a prior alert. | P0 |
| FR-EMG-09 | All user-facing surfaces describing this feature shall carry the positioning/disclaimer language mandated by the OQ-5 resolution. | P0 (launch) |

## 4. Non-Functional Requirements

Numeric targets marked *(prov.)* are provisional pending Phase 0 spike data; workhorses update them via the Decisions Log in `agents.md`, never silently.

### 4.1 Offline Data Integrity & Reconciliation
- NFR-INT-01: No accepted offline action (voucher, claim, acknowledgment) shall be lost prior to successful upload; queued data survives app restarts and device reboots. **P0**
- NFR-INT-02: Reconciliation shall be deterministic: the same set of uploaded records yields the same ledger outcome regardless of upload order or which mule delivered them. **P0**
- NFR-INT-03: Wallet conflict-resolution rules: a voucher identifier accepted by a vendor settles at most once; duplicate submissions of the same voucher are idempotent; two *distinct* vouchers whose sum exceeds the loaded balance constitute a double-spend conflict, which shall be flagged (not silently settled) and routed to the OQ-3 dispute process; vendor-accepted vouchers take precedence over device-local balance claims. **P0**
- NFR-INT-04: The system shall tolerate device clock skew of at least ±5 minutes *(prov.)* in validity-window and expiry evaluation (see OQ-10). **P0**

### 4.2 Battery Efficiency
- NFR-BAT-01: Background mesh participation (discovery + relay, no active feature) shall consume no more than 8% *(prov.)* of battery per hour on supported devices. **P0**
- NFR-BAT-02: A 10-minute Compass finding session shall consume no more than 3% *(prov.)* of battery. **P0**
- NFR-BAT-03: Data-mule upload activity shall be rate-limited and shall not run when device battery is below 20% unless the user opts in. **P0**

### 4.3 Mesh Range, Reliability & Latency
- NFR-MSH-01: An emergency alert shall reach ≥99% of mesh-participating devices in the venue within 120 seconds *(prov.)* under dense-crowd conditions. **P0**
- NFR-MSH-02: Non-emergency broadcasts shall reach ≥90% of participating devices within 5 minutes *(prov.)*. **P0**
- NFR-MSH-03: A store-and-forward message shall be delivered to a device that joins the mesh within the message validity window with ≥95% probability *(prov.)*. **P0**
- NFR-MSH-04: A voucher exchange between attendee and vendor devices at point-of-sale range shall complete within 10 seconds *(prov.)* end to end. **P0**
- NFR-MSH-05: Compass direction/distance shall refresh at least once per second in precise mode *(prov.)*. **P0**
- NFR-MSH-06: The mesh shall degrade gracefully (no crash, no queue corruption) under mass join/leave events such as gates opening. **P0**

### 4.4 Security
- NFR-SEC-01: All vouchers, emergency alerts, and vendor broadcasts shall be signed; devices shall reject unverifiable content (tamper resistance at the message level). **P0**
- NFR-SEC-02: Voucher replay shall be prevented by single-use unique identifiers and vendor-side duplicate rejection; pre-reconciliation double-spend across *different* vendors shall be bounded by per-voucher and per-vault limits set under OQ-3 and detected at reconciliation per NFR-INT-03. **P0**
- NFR-SEC-03: Vault credentials and balance shall be protected by device secure storage; extraction or modification outside defined flows shall be infeasible without compromising the device itself. **P0**
- NFR-SEC-04: Mule-relayed voucher records shall be end-to-end encrypted such that relaying devices cannot read or alter them. **P0**
- NFR-SEC-05: The mesh layer shall bound resource consumption from malformed or flooded messages (fuzzing resilience, storm damping). **P0**
- NFR-SEC-06: Organizer and vendor signing credentials shall be revocable; devices shall honor revocations delivered via cache update or signed mesh message. **P1**

### 4.5 Data Privacy
- NFR-PRV-01: Compass ranging data is ephemeral: never retained beyond the session, never uploaded, never used for any purpose other than the live arrow/distance display (restates FR-CMP-07 as a system-wide guarantee including analytics and crash logs). **P0**
- NFR-PRV-02: Pairing requires symmetric explicit consent; discoverability is off by default until the user enables the feature. **P0**
- NFR-PRV-03: Mesh participation shall not expose a user's identity to non-paired peers beyond what the transport minimally requires; relayed payloads identify users only in encrypted form. **P0**
- NFR-PRV-04: Data-mule relaying shall not reveal to the mule which nearby user a record belongs to. **P0**
- NFR-PRV-05: All collection/retention behavior shall conform to the OQ-4 privacy review outcome and applicable law (including Indian data-protection requirements, given the deployment context). **P0**

## 5. Constraints & Assumptions

**Constraints**
- C-01: iOS only; attendee devices are iPhones, vendor devices are iPads, both running the District app/add-on.
- C-02: Transport is Apple Multipeer Connectivity over short-range device radio (Bluetooth / peer Wi-Fi); no third-party mesh SDK and no venue-installed network hardware are assumed.
- C-03: iOS platform limits on background execution and radio use constrain mesh participation when the app is backgrounded or the device is locked (OQ-6); requirements in §4.3 apply to foreground-participating devices unless OQ-6 resolves otherwise.
- C-04: Vault funding (F1) and cache download (F0) require pre-event connectivity; the offline experience assumes users completed both before entry.
- C-05: F1 settlement ultimately depends on central services; the offline system defers, it does not replace, authoritative settlement.
- C-06: App Store review policy constrains the wallet flow; design must conform to whatever OQ-2 concludes.

**Assumptions**
- A-01: A meaningful fraction of attendees at a venue run District with mesh enabled; feature value (especially F4 reach and mule frequency) scales with adoption (OQ-8).
- A-02: Vendors are enrolled, credentialed, and equipped with iPads before the event (OQ-9).
- A-03: Organizers are willing and contractually able to operate F4 (OQ-5).
- A-04: Some connectivity exists at venue edges or via vendor uplinks often enough for data-mule reconciliation to complete within hours, not days.
- A-05: Provisional numeric targets in §4 will be re-baselined from Phase 0 spike data.

## 6. Open Questions (require sign-off before the tagged work proceeds; owners TBD)

| ID | Question | Needs | Blocks |
|----|----------|-------|--------|
| OQ-1 | ~~Transport selection.~~ **RESOLVED 2026-07-18:** transport is Apple Multipeer Connectivity (native), no third-party SDK, no fallback. Retained here as a stable ID for cross-references; no longer blocking. | — (decided) | — (closed) |
| OQ-2 | Offline vouchers move real money via Bluetooth outside a live payment processor. Does this trigger payment-services / stored-value / e-money regulation in target jurisdictions (deployment context includes India — e.g., PPI regulation)? Does an SDK-mediated offline payment flow raise Apple App Store review concerns, and what flow shape would be approvable? | Legal/compliance + App Store counsel | All F1 work (Phase 4) |
| OQ-3 | Voucher fraud model: what bounds the replay/double-spend window before mule reconciliation (per-voucher caps? per-vault caps? vendor float?), who bears loss on conflict, and what is the user-facing dispute process? | Legal + finance + security | Phase 4 policy design; Phase 4 exit tests |
| OQ-4 | Compass privacy: exact consent language, opt-out surfaces, minor-user handling, and confirmation that zero retention (NFR-PRV-01) satisfies applicable law. | Privacy/legal | F2 beta ship |
| OQ-5 | Can F4 be marketed or contractually relied upon as a life-safety system given mesh propagation limits and dead-zone risk, or must it be positioned strictly as supplementary to official emergency communications — and what disclaimer/liability language follows? | Legal + marketing + organizer stakeholders | F4 launch positioning (FR-EMG-09) |
| OQ-6 | How severely do iOS background-execution limits reduce mesh participation for backgrounded/locked devices, and does any mitigation exist within App Store policy? Silent risk to F4 reach and mule frequency. | Engineering (Phase 0/1 findings) + stakeholder acceptance of residual limits | Phase 1 design sign-off |
| OQ-7 | Practical peer/session ceilings of the chosen transport at venue scale (thousands of devices): what topology-management strategy keeps the mesh functional? | Engineering (Phase 0 spike) | Phase 1 |
| OQ-8 | Participation death spiral: if battery cost drives users to disable mesh, coverage collapses for everyone. What adoption/battery threshold makes the system viable, and is there a product mitigation (incentives, event-mode prompt)? | Product + engineering | Phase 5 go/no-go |
| OQ-9 | Vendor logistics: enrollment, credential issuance/rotation, iPad provisioning, and what happens when a vendor device is lost mid-event. | Operations + security | Phase 4/5 |
| OQ-10 | Offline clock skew: is ±5 minutes tolerance sufficient for voucher timestamps, alert validity windows, and surplus expiry, and how is skew bounded without connectivity? | Engineering | Phase 1 design |
