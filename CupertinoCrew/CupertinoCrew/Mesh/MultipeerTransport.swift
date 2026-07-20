import Foundation
import MultipeerConnectivity
import Combine
import UIKit
import Network

/// Real Multipeer Connectivity transport: advertises, browses, auto-connects,
/// and moves raw bytes over Bluetooth/Wi-Fi with no internet involved.
///
/// Service type here must match the Bonjour service names declared in
/// Info.plist (NSBonjourServices: _district-mesh._tcp / _udp).
final class MultipeerTransport: NSObject, MeshTransport {
	private static let serviceType = "district-mesh"

	let localPeerID: String

	private let myPeerID: MCPeerID
	// Rebuilt from scratch on every start()/restart — an MCSession is not reliably reusable after
	// disconnect(), so reusing the same instance across a Wi-Fi/Bluetooth toggle produces silent
	// connect failures (advertising/browsing look alive, invites send, but state never reaches
	// .connected). `var`, not `let`, precisely so rebuildStack() can swap in fresh objects.
	private var session: MCSession
	private var advertiser: MCNearbyServiceAdvertiser
	private var browser: MCNearbyServiceBrowser
	private let sessionID = UUID().uuidString

	private let peerCountSubject = CurrentValueSubject<Int, Never>(0)
	private let connectedPeerIDsSubject = CurrentValueSubject<[String], Never>([])
	private let isRunningSubject = CurrentValueSubject<Bool, Never>(false)
	private let peerConnectedSubject = PassthroughSubject<String, Never>()
	private let messageReceivedSubject = PassthroughSubject<(data: Data, from: String), Never>()

	var peerCountPublisher: AnyPublisher<Int, Never> { peerCountSubject.eraseToAnyPublisher() }
	var connectedPeerIDsPublisher: AnyPublisher<[String], Never> { connectedPeerIDsSubject.eraseToAnyPublisher() }
	var isRunningPublisher: AnyPublisher<Bool, Never> { isRunningSubject.eraseToAnyPublisher() }
	var peerConnected: AnyPublisher<String, Never> { peerConnectedSubject.eraseToAnyPublisher() }
	var messageReceived: AnyPublisher<(data: Data, from: String), Never> { messageReceivedSubject.eraseToAnyPublisher() }

	// MARK: - Network path recovery
	// The advertiser/browser don't reliably self-heal after Wi-Fi/Bluetooth or Airplane Mode
	// toggles (which is the environment this app runs in constantly). Watch the active path
	// and force a clean stop/start whenever the interfaces available to it actually change.
	private let pathMonitor = NWPathMonitor()
	private let pathMonitorQueue = DispatchQueue(label: "district-mesh.path-monitor")
	private var lastPathSignature: String?
	private var restartWorkItem: DispatchWorkItem?
	private var inviteTimeoutWorkItems: [String: DispatchWorkItem] = [:]
	private var pendingInvitePeerIDs = Set<String>()
	private var connectedPeerIDs = Set<String>()
	private var sessionStates: [String: String] = [:]
	private let sessionStateLock = NSLock()
	private var isRestartInProgress = false
	private var isAdvertising = false
	private var isBrowsing = false
	private var hasStarted = false

	init(displayName: String = UIDevice.current.name) {
		// Identity requirements, both of which must hold at once:
		//  (1) unique per device — otherwise two devices sharing a `UIDevice.name` (common in
		//      a test fleet of un-renamed "iPhone"s) collide into one identity, so the admin's
		//      own member ID equals a connected peer's ID and that peer is filtered out of the
		//      invite list (and membership silently breaks);
		//  (2) shareable — the SAME string must be what remote peers see, since peers only ever
		//      refer to each other by `stableID(for:)` == `MCPeerID.displayName` (which fills
		//      `connectedPeerIDs`, `peerConnected`, and the `from` on received packets).
		// The token is therefore baked into the MCPeerID displayName ITSELF (so Multipeer
		// propagates it to peers), not appended only to the local `localPeerID` (which peers
		// never see — that was the previous bug). `identifierForVendor` is stable per install,
		// giving a persistent unique suffix. Result: local self-ID, peer-visible stableID, and
		// connectedPeerIDs are all the same unique-and-shared string.
		let token = UIDevice.current.identifierForVendor?.uuidString.prefix(8).description ?? "0000"
		let uniqueName = "\(displayName)#\(token)"
		let peerID = MCPeerID(displayName: uniqueName)
		self.myPeerID = peerID
		self.localPeerID = peerID.displayName
		self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
		self.advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
		self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
		super.init()
		session.delegate = self
		advertiser.delegate = self
		browser.delegate = self
		log("mc_session_created", sessionState: "notConnected")
		log("advertiser_created")
		log("browser_created")
		log("transport_initialized")
		pathMonitor.pathUpdateHandler = { [weak self] path in self?.handlePathUpdate(path) }
		pathMonitor.start(queue: pathMonitorQueue)
	}

	deinit {
		pathMonitor.cancel()
	}

	func start() {
		guard !hasStarted else {
			log("transport_start_skipped", fields: ["reason": "already_started"])
			return
		}
		hasStarted = true
		// Fresh session/advertiser/browser every start. The old ones may have had disconnect()
		// called on them (via stop()); Apple's stack does not reliably recover a used session.
		rebuildStack()
		if !isAdvertising {
			advertiser.startAdvertisingPeer()
			isAdvertising = true
		}
		if !isBrowsing {
			browser.startBrowsingForPeers()
			isBrowsing = true
		}
		isRunningSubject.send(true)
		log("transport_started")
		log("advertiser_state", fields: ["state": "started"])
		log("browser_state", fields: ["state": "started"])
	}

	func stop() {
		guard hasStarted else {
			log("transport_stop_skipped", fields: ["reason": "already_stopped"])
			return
		}
		hasStarted = false
		restartWorkItem?.cancel()
		restartWorkItem = nil
		if isAdvertising {
			advertiser.stopAdvertisingPeer()
			isAdvertising = false
		}
		if isBrowsing {
			browser.stopBrowsingForPeers()
			isBrowsing = false
		}
		cancelPendingInvites()
		connectedPeerIDs.removeAll()
		session.disconnect()
		connectedPeerIDsSubject.send([])
		isRunningSubject.send(false)
		log("transport_stopped")
		log("advertiser_state", fields: ["state": "stopped"])
		log("browser_state", fields: ["state": "stopped"])
	}

	/// Tears down the current Multipeer stack and builds brand-new session/advertiser/browser
	/// instances wired to this transport. Must run on the same (main) queue as start()/stop()
	/// so `isAdvertising`/`isBrowsing` and the object swap stay consistent. Callers are
	/// responsible for having stopped advertising/browsing on the old objects first (stop() does).
	private func rebuildStack() {
		// Detach delegates from the outgoing objects so any late callbacks from them are ignored.
		advertiser.delegate = nil
		browser.delegate = nil
		session.delegate = nil
		session.disconnect()

		let freshSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
		let freshAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: Self.serviceType)
		let freshBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
		freshSession.delegate = self
		freshAdvertiser.delegate = self
		freshBrowser.delegate = self
		session = freshSession
		advertiser = freshAdvertiser
		browser = freshBrowser

		// The old session is gone; its per-peer state is meaningless on the new one.
		connectedPeerIDs.removeAll()
		cancelPendingInvites()
		sessionStateLock.lock()
		sessionStates.removeAll()
		sessionStateLock.unlock()
		log("mc_session_rebuilt", sessionState: "notConnected")
	}

	/// Restarts advertising/browsing when the set of usable interfaces (Wi-Fi/Bluetooth
	/// availability, satisfied/unsatisfied status) actually changes — not on every callback,
	/// since NWPathMonitor can fire several transient updates in quick succession mid-toggle.
	private func handlePathUpdate(_ path: NWPath) {
		let interfaces = path.availableInterfaces.map { "\($0.type)" }.sorted().joined(separator: ",")
		let signature = "\(path.status)|\(interfaces)"
		log("actor_hop_scheduled", fields: ["destination": "main", "source": "NWPathMonitor"])
		DispatchQueue.main.async { [weak self] in
			self?.log("actor_hop_enter", fields: ["destination": "main", "source": "NWPathMonitor"])
			defer { self?.log("actor_hop_exit", fields: ["destination": "main", "source": "NWPathMonitor"]) }
			self?.handlePathSignature(signature)
		}
	}

	private func handlePathSignature(_ signature: String) {
		guard signature != lastPathSignature else { return }
		lastPathSignature = signature
		guard hasStarted else { return } // nothing to recover if we were never started or stopped intentionally
		log("reconnect_attempt_scheduled", fields: ["path": signature])

		restartWorkItem?.cancel()
		let work = DispatchWorkItem { [weak self] in
			guard let self, self.hasStarted, !self.isRestartInProgress else { return }
			self.isRestartInProgress = true
			defer {
				self.isRestartInProgress = false
				self.restartWorkItem = nil
			}
			self.log("reconnect_attempt", fields: ["path": signature])
			self.stop()
			self.start()
		}
		restartWorkItem = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
	}

	func broadcast(_ data: Data) throws {
		let peers = session.connectedPeers
		guard !peers.isEmpty else {
			log("packet_send_skipped", fields: ["reason": "no_connected_peers"], packetSize: data.count)
			return
		}
		log("packet_send", fields: ["destination": peers.map(stableID(for:)).joined(separator: ",")], packetSize: data.count)
		do {
			try session.send(data, toPeers: peers, with: .reliable)
			log("packet_send_completed", fields: ["destination": peers.map(stableID(for:)).joined(separator: ",")], packetSize: data.count)
		} catch {
			log("packet_send_failed", fields: ["error": error.localizedDescription], packetSize: data.count)
			throw error
		}
	}

	func send(_ data: Data, to peerID: String) throws {
		guard let target = session.connectedPeers.first(where: { $0.displayName == peerID || stableID(for: $0) == peerID }) else {
			log("packet_send_skipped", remotePeerID: peerID, fields: ["reason": "peer_not_connected"], packetSize: data.count)
			return
		}
		log("packet_send", remotePeerID: peerID, fields: ["destination": peerID], packetSize: data.count)
		do {
			try session.send(data, toPeers: [target], with: .reliable)
			log("packet_send_completed", remotePeerID: peerID, fields: ["destination": peerID], packetSize: data.count)
		} catch {
			log("packet_send_failed", remotePeerID: peerID, fields: ["error": error.localizedDescription], packetSize: data.count)
			throw error
		}
	}

	private func stableID(for peer: MCPeerID) -> String {
		peer.displayName
	}

	private func log(_ event: String, remotePeerID: String? = nil, fields: [String: String] = [:], function: String = #function, sessionState: String? = nil, packetType: String = "unknown", packetSize: Int? = nil) {
		MeshDiagnostics.log(event, localPeerID: localPeerID, remotePeerID: remotePeerID, sessionID: sessionID, fields: fields, function: function, sessionState: sessionState ?? sessionStateSummary, packetType: packetType, packetSize: packetSize)
	}

	private var sessionStateSummary: String {
		sessionStateLock.lock()
		defer { sessionStateLock.unlock() }
		return sessionStates.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
	}

	private func setSessionState(_ state: String, for remoteID: String) {
		sessionStateLock.lock()
		sessionStates[remoteID] = state
		sessionStateLock.unlock()
	}

	private func currentSessionState(for remoteID: String) -> String {
		sessionStateLock.lock()
		defer { sessionStateLock.unlock() }
		return sessionStates[remoteID] ?? "unknown"
	}

	private func cancelPendingInvites() {
		inviteTimeoutWorkItems.values.forEach { $0.cancel() }
		inviteTimeoutWorkItems.removeAll()
		pendingInvitePeerIDs.removeAll()
	}
}

extension MultipeerTransport: MCSessionDelegate {
	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		let remoteID = stableID(for: peerID)
		let stateDescription = "\(state)"
		let previousState = currentSessionState(for: remoteID)
		let function = "session(_:peer:didChange:)"
		log("delegate_enter", remotePeerID: remoteID, fields: ["callback": "didChange", "previousState": previousState, "newState": stateDescription], function: function, sessionState: "\(previousState)->\(stateDescription)")
		defer { log("delegate_exit", remotePeerID: remoteID, fields: ["callback": "didChange", "previousState": previousState, "newState": stateDescription], function: function, sessionState: stateDescription) }
		log("session_state_changed", remotePeerID: remoteID, fields: ["state": stateDescription, "connectedPeerCount": "\(session.connectedPeers.count)", "previousState": previousState], function: function, sessionState: "\(previousState)->\(stateDescription)")
		log("actor_hop_scheduled", remotePeerID: remoteID, fields: ["destination": "main"], function: function, sessionState: stateDescription)
		DispatchQueue.main.async {
			self.log("actor_hop_enter", remotePeerID: remoteID, fields: ["destination": "main", "callback": "didChange"], function: function, sessionState: stateDescription)
			defer { self.log("actor_hop_exit", remotePeerID: remoteID, fields: ["destination": "main", "callback": "didChange"], function: function, sessionState: stateDescription) }
			if state == .connected {
				if !self.hasStarted {
					self.log("session_state_invalid", remotePeerID: remoteID, fields: ["reason": "connected_while_transport_stopped"], sessionState: stateDescription)
				}
				if self.connectedPeerIDs.contains(remoteID) {
					self.log("session_state_duplicate", remotePeerID: remoteID, fields: ["state": stateDescription], sessionState: stateDescription)
				}
				self.connectedPeerIDs.insert(remoteID)
				self.setSessionState(stateDescription, for: remoteID)
			} else {
				self.connectedPeerIDs.remove(remoteID)
				self.setSessionState(stateDescription, for: remoteID)
			}
			self.peerCountSubject.send(session.connectedPeers.count)
			self.connectedPeerIDsSubject.send(session.connectedPeers.map(self.stableID(for:)))
			if state == .connected {
				self.inviteTimeoutWorkItems[remoteID]?.cancel()
				self.inviteTimeoutWorkItems.removeValue(forKey: remoteID)
				self.pendingInvitePeerIDs.remove(remoteID)
				self.peerConnectedSubject.send(self.stableID(for: peerID))
			}
		}
	}

	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		let remoteID = stableID(for: peerID)
		let function = "session(_:didReceive:fromPeer:)"
		let state = currentSessionState(for: remoteID)
		log("delegate_enter", remotePeerID: remoteID, fields: ["callback": "didReceiveData", "previousState": state, "newState": state], function: function, sessionState: state, packetSize: data.count)
		defer { log("delegate_exit", remotePeerID: remoteID, fields: ["callback": "didReceiveData", "previousState": state, "newState": state], function: function, sessionState: state, packetSize: data.count) }
		log("packet_receive", remotePeerID: remoteID, function: function, sessionState: state, packetSize: data.count)
		log("packet_receive_delivery_started", remotePeerID: remoteID, function: function, sessionState: state, packetSize: data.count)
		messageReceivedSubject.send((data: data, from: stableID(for: peerID)))
		log("packet_receive_delivery_completed", remotePeerID: remoteID, function: function, sessionState: state, packetSize: data.count)
	}

	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
		let remoteID = stableID(for: peerID)
		let function = "session(_:didReceive:withName:fromPeer:)"
		let state = currentSessionState(for: remoteID)
		log("delegate_enter", remotePeerID: remoteID, fields: ["callback": "didReceiveStream", "streamName": streamName, "previousState": state, "newState": state], function: function, sessionState: state)
		defer { log("delegate_exit", remotePeerID: remoteID, fields: ["callback": "didReceiveStream", "streamName": streamName, "previousState": state, "newState": state], function: function, sessionState: state) }
		log("stream_receive_ignored", remotePeerID: remoteID, fields: ["streamName": streamName], function: function, sessionState: state)
	}

	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
		let remoteID = stableID(for: peerID)
		let function = "session(_:didStartReceivingResourceWithName:fromPeer:with:)"
		let state = currentSessionState(for: remoteID)
		log("delegate_enter", remotePeerID: remoteID, fields: ["callback": "didStartReceivingResource", "resourceName": resourceName, "previousState": state, "newState": state, "progress": "\(progress.fractionCompleted)"], function: function, sessionState: state)
		defer { log("delegate_exit", remotePeerID: remoteID, fields: ["callback": "didStartReceivingResource", "resourceName": resourceName, "previousState": state, "newState": state], function: function, sessionState: state) }
	}

	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
		let remoteID = stableID(for: peerID)
		let function = "session(_:didFinishReceivingResourceWithName:fromPeer:at:withError:)"
		let state = currentSessionState(for: remoteID)
		log("delegate_enter", remotePeerID: remoteID, fields: ["callback": "didFinishReceivingResource", "resourceName": resourceName, "previousState": state, "newState": state, "localURL": localURL?.path ?? "-", "error": error?.localizedDescription ?? "-"], function: function, sessionState: state)
		defer { log("delegate_exit", remotePeerID: remoteID, fields: ["callback": "didFinishReceivingResource", "resourceName": resourceName, "previousState": state, "newState": state], function: function, sessionState: state) }
	}

	func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
		let remoteID = stableID(for: peerID)
		let function = "session(_:didReceiveCertificate:fromPeer:certificateHandler:)"
		let state = currentSessionState(for: remoteID)
		log("delegate_enter", remotePeerID: remoteID, fields: ["callback": "didReceiveCertificate", "certificateCount": "\(certificate?.count ?? 0)", "previousState": state, "newState": state], function: function, sessionState: state)
		defer { log("delegate_exit", remotePeerID: remoteID, fields: ["callback": "didReceiveCertificate", "previousState": state, "newState": state], function: function, sessionState: state) }
		log("certificate_decision", remotePeerID: remoteID, fields: ["accepted": "true"], function: function, sessionState: state)
		certificateHandler(true)
	}
}

extension MultipeerTransport: MCNearbyServiceAdvertiserDelegate {
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
		let remoteID = stableID(for: peerID)
		log("invite_started", remotePeerID: remoteID)
		// Hackathon scope: mesh membership itself is auto-accepted (untrusted transport by design,
		// per SRD trust model — every message is verified at the feature layer, not the transport).
		let shouldAcceptInvitation = true
		log(shouldAcceptInvitation ? "invite_accepted" : "invite_rejected", remotePeerID: remoteID)
		invitationHandler(shouldAcceptInvitation, shouldAcceptInvitation ? session : nil)
	}

	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
		log("advertiser_state", fields: ["state": "failed", "error": error.localizedDescription])
	}
}

extension MultipeerTransport: MCNearbyServiceBrowserDelegate {
	func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
		guard peerID != myPeerID else { return }
		let remoteID = stableID(for: peerID)
		log("peer_discovered", remotePeerID: remoteID)
		guard !session.connectedPeers.contains(where: { stableID(for: $0) == remoteID }) else {
			log("invite_skipped", remotePeerID: remoteID, fields: ["reason": "already_connected"])
			return
		}
		guard !pendingInvitePeerIDs.contains(remoteID) else {
			log("invite_skipped", remotePeerID: remoteID, fields: ["reason": "already_pending"])
			return
		}
		pendingInvitePeerIDs.insert(remoteID)
		log("invite_started", remotePeerID: remoteID, fields: ["timeoutSeconds": "15"])
		browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
		inviteTimeoutWorkItems[remoteID]?.cancel()
		let timeoutWork = DispatchWorkItem { [weak self] in
			guard let self, self.session.connectedPeers.contains(where: { self.stableID(for: $0) == remoteID }) == false else { return }
			self.log("invite_timeout", remotePeerID: remoteID, fields: ["timeoutSeconds": "15"])
			self.inviteTimeoutWorkItems.removeValue(forKey: remoteID)
			self.pendingInvitePeerIDs.remove(remoteID)
		}
		inviteTimeoutWorkItems[remoteID] = timeoutWork
		DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeoutWork)
	}

	func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
		let remoteID = stableID(for: peerID)
		log("peer_lost", remotePeerID: remoteID)
		inviteTimeoutWorkItems[remoteID]?.cancel()
		inviteTimeoutWorkItems.removeValue(forKey: remoteID)
		pendingInvitePeerIDs.remove(remoteID)
		log("actor_hop_scheduled", remotePeerID: remoteID, fields: ["destination": "main", "source": "MCNearbyServiceBrowserDelegate.lostPeer"])
		DispatchQueue.main.async {
			self.log("actor_hop_enter", remotePeerID: remoteID, fields: ["destination": "main", "source": "MCNearbyServiceBrowserDelegate.lostPeer"])
			defer { self.log("actor_hop_exit", remotePeerID: remoteID, fields: ["destination": "main", "source": "MCNearbyServiceBrowserDelegate.lostPeer"]) }
			self.peerCountSubject.send(self.session.connectedPeers.count)
			self.connectedPeerIDsSubject.send(self.session.connectedPeers.map(self.stableID(for:)))
		}
	}

	func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
		log("browser_state", fields: ["state": "failed", "error": error.localizedDescription])
	}
}
