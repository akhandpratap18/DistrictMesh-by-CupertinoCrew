import SwiftUI

/// Always-visible strip: live connected peer count + OFFLINE indicator.
/// Every value here comes straight from MessageBus/MeshTransport state — nothing hardcoded.
struct MeshStatusView: View {
	@ObservedObject var bus: MessageBus

	private var statusText: String {
		if bus.peerCount > 0 {
			return "\(bus.peerCount) peer\(bus.peerCount == 1 ? "" : "s")"
		} else if bus.isRunning {
			return "Searching for peers…"
		} else {
			return "Not searching"
		}
	}

	private var statusColor: Color {
		if bus.peerCount > 0 { return .green }
		if bus.isRunning { return .orange }
		return .red
	}

	var body: some View {
		HStack(spacing: 8) {
			Circle()
				.fill(statusColor)
				.frame(width: 8, height: 8)
			Text(statusText)
				.font(.caption).bold()
			Spacer()
			Label("OFFLINE / no internet", systemImage: "wifi.slash")
				.font(.caption2)
				.foregroundStyle(.secondary)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 6)
		.background(.thinMaterial)
	}
}
