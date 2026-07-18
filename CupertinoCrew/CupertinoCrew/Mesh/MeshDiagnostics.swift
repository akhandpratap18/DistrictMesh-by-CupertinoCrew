import Foundation
import os

/// Structured, local-only diagnostics for the mesh transport and message bus.
///
/// The log payload deliberately includes the fields needed to correlate events
/// across devices. It does not change transport or routing behavior.
enum MeshDiagnostics {
	private static let logger = Logger(subsystem: "com.cupertinocrew.CupertinoCrew", category: "mesh")
	private static let timestampLock = NSLock()

	static func log(
		_ event: String,
		localPeerID: String,
		remotePeerID: String? = nil,
		sessionID: String,
		fields: [String: String] = [:],
		function: String = #function,
		sessionState: String = "unknown",
		packetType: String = "unknown",
		packetSize: Int? = nil
	) {
		var payload = fields
		payload["event"] = event
		payload["function"] = function
		payload["sessionState"] = sessionState
		payload["packetType"] = packetType
		payload["packetSize"] = packetSize.map(String.init) ?? "unknown"
		timestampLock.lock()
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		payload["timestamp"] = formatter.string(from: Date())
		timestampLock.unlock()
		payload["localPeerID"] = localPeerID
		payload["remotePeerID"] = remotePeerID ?? "-"
		payload["thread"] = Thread.isMainThread ? "main" : "background"
		payload["sessionID"] = sessionID

		let orderedPayload = payload.keys.sorted().reduce(into: [String: String]()) { result, key in
			result[key] = payload[key]
		}
		guard let data = try? JSONSerialization.data(withJSONObject: orderedPayload, options: [.sortedKeys]),
			  let message = String(data: data, encoding: .utf8) else {
			return
		}
		logger.debug("\(message, privacy: .public)")
	}
}
