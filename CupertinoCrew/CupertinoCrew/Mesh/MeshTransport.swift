import Foundation
import Combine

/// Internal seam so feature code never touches MultipeerConnectivity directly.
/// One transport is planned (Multipeer) but every feature layer talks only to this protocol.
protocol MeshTransport: AnyObject {
	/// Stable local identifier used as originPeerID / relay identity.
	var localPeerID: String { get }

	/// Number of currently connected peers, live.
	var peerCountPublisher: AnyPublisher<Int, Never> { get }

	/// True once advertising+browsing are running (does not imply any peers connected).
	var isRunningPublisher: AnyPublisher<Bool, Never> { get }

	/// Fires with the peer's stable ID whenever a new peer connects, so the
	/// message bus can push its store-and-forward backlog to that peer.
	var peerConnected: AnyPublisher<String, Never> { get }

	/// Raw bytes received from any peer, with the sender's stable ID.
	var messageReceived: AnyPublisher<(data: Data, from: String), Never> { get }

	func start()
	func stop()

	/// Best-effort send to every connected peer.
	func broadcast(_ data: Data) throws

	/// Best-effort send to one specific peer (used for backlog catch-up).
	func send(_ data: Data, to peerID: String) throws
}
