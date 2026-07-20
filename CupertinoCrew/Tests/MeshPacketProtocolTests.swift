// Phase 5 protocol correctness harness.
//
// These are pure-logic tests against the real, unmodified Foundation-only model
// sources (`Mesh/MeshMessage.swift`, `Mesh/MeshStats.swift`). They intentionally live
// OUTSIDE the Xcode synchronized source group so they are never compiled into the app
// target (the project has no XCTest target — see agents.md). Run standalone:
//
//   swiftc -parse-as-library \
//     CupertinoCrew/CupertinoCrew/Mesh/MeshMessage.swift \
//     CupertinoCrew/CupertinoCrew/Mesh/MeshStats.swift \
//     CupertinoCrew/Tests/MeshPacketProtocolTests.swift -o /tmp/meshtests && /tmp/meshtests
//
// A future engineer can lift these assertions into a real XCTest target verbatim.

import Foundation

private var failures = 0
private func check(_ cond: Bool, _ label: String) {
	if cond { print("  ok   \(label)") } else { failures += 1; print("  FAIL \(label)") }
}

// 1. Round-trip serialize/deserialize of a fully-populated packet.
private func testRoundTrip() {
	print("[round-trip serialize/deserialize]")
	let packet = MeshPacket(
		type: .text, priority: .high, originPeerID: "A-1111",
		validFor: 300, hopCount: 2, maxHops: 6, payload: Data("hi".utf8),
		previousHopPeerID: "B-2222", destinationPeerID: "C-3333", groupID: "g-42"
	)
	let data = try! JSONEncoder().encode(packet)
	let decoded = try! JSONDecoder().decode(MeshPacket.self, from: data)
	check(decoded == packet, "decoded == original (all fields incl. new optionals)")
	check(decoded.destinationPeerID == "C-3333", "destinationPeerID survives")
	check(decoded.previousHopPeerID == "B-2222", "previousHopPeerID survives")
	check(decoded.groupID == "g-42", "groupID survives")
}

// 2. Backward compatibility: a Phase 1–4 wire packet (no Phase 5 keys) still decodes.
//    Derive the legacy byte set format-agnostically: encode a real packet with the same
//    encoder the app uses, strip the Phase 5 keys from the JSON object (simulating a byte
//    set produced by an old build that never knew those keys), then decode it back.
private func testBackwardDecode() {
	print("[backward compat: legacy wire packet without Phase 5 keys]")
	let full = MeshPacket(
		type: .ping, priority: .normal, originPeerID: "A", validFor: 300,
		hopCount: 1, maxHops: 6, payload: Data("legacy".utf8),
		previousHopPeerID: "X", destinationPeerID: "Y", groupID: "Z"
	)
	var obj = try! JSONSerialization.jsonObject(with: try! JSONEncoder().encode(full)) as! [String: Any]
	for k in ["previousHopPeerID", "destinationPeerID", "groupID"] { obj.removeValue(forKey: k) }
	let legacyData = try! JSONSerialization.data(withJSONObject: obj)
	let decoded = try! JSONDecoder().decode(MeshPacket.self, from: legacyData)
	check(decoded.type == .ping, "legacy type decodes")
	check(decoded.hopCount == 1, "legacy hopCount decodes")
	check(decoded.destinationPeerID == nil, "missing destinationPeerID → nil")
	check(decoded.groupID == nil, "missing groupID → nil")
	check(decoded.previousHopPeerID == nil, "missing previousHopPeerID → nil")
	check(String(data: decoded.payload, encoding: .utf8) == "legacy", "legacy payload decodes")
}

// 3. Forward compatibility shape: nil optionals are OMITTED from the wire (encodeIfPresent),
//    so a new build sending to an old build produces a byte-set the old decoder accepts.
private func testForwardWireShape() {
	print("[forward compat: nil optionals omitted from JSON]")
	let packet = MeshPacket(type: .ping, priority: .normal, originPeerID: "A", validFor: 45, payload: Data())
	let json = String(data: try! JSONEncoder().encode(packet), encoding: .utf8)!
	check(!json.contains("destinationPeerID"), "no destinationPeerID key when nil")
	check(!json.contains("groupID"), "no groupID key when nil")
	check(!json.contains("previousHopPeerID"), "no previousHopPeerID key when nil")
	check(json.contains("\"originPeerID\""), "legacy keys still present")
}

// 4. Hop count increments EXACTLY once per relay, and never on origin send.
private func testHopIncrementOnce() {
	print("[hop count: exactly once per relay]")
	let origin = MeshPacket(type: .text, priority: .normal, originPeerID: "A", validFor: 300, payload: Data())
	check(origin.hopCount == 0, "origin packet starts at hop 0")
	let h1 = origin.relayed(previousHop: "A")
	check(h1.hopCount == 1, "one relay → hop 1")
	check(origin.hopCount == 0, "relaying does not mutate the source (value semantics)")
	let h2 = h1.relayed(previousHop: "B")
	let h3 = h2.relayed(previousHop: "C")
	check(h2.hopCount == 2 && h3.hopCount == 3, "each relay adds exactly 1 (2,3)")
	check(h3.previousHopPeerID == "C", "previousHop stamped on each relay")
}

// 5. TTL/hop-budget expiry gates relaying (loop/storm bound at maxHops).
private func testExpiryBudget() {
	print("[expiry: hop budget + validity]")
	let atLimit = MeshPacket(type: .text, priority: .normal, originPeerID: "A", validFor: 300, hopCount: 6, maxHops: 6, payload: Data())
	check(atLimit.isExpired, "hopCount == maxHops → expired")
	let expiredTime = MeshPacket(type: .text, priority: .normal, originPeerID: "A", validFor: -1, payload: Data())
	check(expiredTime.isExpired, "past validUntil → expired")
	let live = MeshPacket(type: .text, priority: .normal, originPeerID: "A", validFor: 300, hopCount: 5, maxHops: 6, payload: Data())
	check(!live.isExpired && live.relayed().isExpired, "last legal hop relays to an expired copy (flood stops)")
}

// 6. ACK payload round-trips and addressing helper is correct.
private func testAckPayloadAndAddressing() {
	print("[ack payload + addressing]")
	let acked = UUID()
	let payload = AckPayload(acknowledgedPacketID: acked)
	let decoded = try! JSONDecoder().decode(AckPayload.self, from: try! JSONEncoder().encode(payload))
	check(decoded.acknowledgedPacketID == acked, "AckPayload round-trips")
	let directed = MeshPacket(type: .text, priority: .normal, originPeerID: "A", validFor: 300, payload: Data(), destinationPeerID: "C")
	check(directed.isAddressed(to: "C"), "directed packet is addressed to its destination")
	check(!directed.isAddressed(to: "B"), "not addressed to an intermediate")
	let ack = MeshPacket(type: .ack, priority: .normal, originPeerID: "C", validFor: 30, payload: Data(), destinationPeerID: "A")
	check(!ack.isAddressed(to: "A"), "an ACK is never itself ACK-eligible (no ack-of-ack)")
	let broadcast = MeshPacket(type: .text, priority: .normal, originPeerID: "A", validFor: 300, payload: Data())
	check(!broadcast.isAddressed(to: "C"), "broadcast packet (nil destination) is addressed to no one")
}

// 7. New packet types all encode/decode by raw value (no legacy collision).
private func testPacketTypeSystem() {
	print("[packet type system]")
	let all: [MeshMessageType] = [.text, .heartbeat, .ack, .groupInvite, .groupAccept, .groupLeave, .discovery, .payment, .paymentConfirmation, .system, .ping, .emergencyAlert]
	for t in all {
		let round = MeshMessageType(rawValue: t.rawValue)
		check(round == t, "type \(t.rawValue) round-trips")
	}
}

// 8. MeshStats aggregation math (average + maximum hop count).
private func testStatsAggregation() {
	print("[stats aggregation]")
	var s = MeshStats()
	check(s.averageHopCount == 0, "empty average is 0")
	[1, 3, 5].forEach { s.recordHopCount($0) }
	check(s.averageHopCount == 3.0, "average of 1,3,5 == 3.0")
	check(s.maximumHopCountSeen == 5, "max seen == 5")
	s.markActivity()
	check(s.lastActivity != nil, "markActivity sets timestamp")
}

// MARK: - main
@main struct Runner {
	static func main() {
		print("== Phase 5 Mesh Protocol Tests ==")
		testRoundTrip()
		testBackwardDecode()
		testForwardWireShape()
		testHopIncrementOnce()
		testExpiryBudget()
		testAckPayloadAndAddressing()
		testPacketTypeSystem()
		testStatsAggregation()
		print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
		exit(failures == 0 ? 0 : 1)
	}
}
