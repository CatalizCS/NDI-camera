// BonjourAdvertiser.swift
// Remote — Advertises _tamandicam._tcp. service via Bonjour / NWListener.

#if canImport(Network)
import Foundation
import Network

/// Advertises the TamaNDI remote control service over Bonjour (mDNS/DNS-SD).
/// Service type: `_tamandicam._tcp.`
public actor BonjourAdvertiser {

    // MARK: - Constants

    public static let serviceType = "_tamandicam._tcp."
    public static let defaultServiceName = "TamaNDI"

    // MARK: - State

    private var listener: NWListener?
    private(set) public var isAdvertising: Bool = false
    private(set) public var serviceName: String = BonjourAdvertiser.defaultServiceName

    public init() {}

    // MARK: - Lifecycle

    /// Start advertising the service on the specified port.
    /// Uses the existing NWListener's Bonjour parameters if available.
    public func startAdvertising(name: String = defaultServiceName, port: UInt16) throws {
        guard !isAdvertising else { return }

        serviceName = name

        let parameters = NWParameters.tcp
        let nwPort = NWEndpoint.Port(rawValue: port) ?? .any

        let advertiseListener = try NWListener(using: parameters, on: nwPort)

        // Configure Bonjour service
        advertiseListener.service = NWListener.Service(
            name: name,
            type: BonjourAdvertiser.serviceType
        )

        advertiseListener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task {
                await self.handleStateChange(state)
            }
        }

        // We don't need to handle connections on this listener —
        // the HTTPServer handles connections. This is purely for advertisement.
        advertiseListener.newConnectionHandler = { connection in
            connection.cancel()
        }

        let queue = DispatchQueue(label: "com.tamandicam.bonjour", qos: .utility)
        advertiseListener.start(queue: queue)

        listener = advertiseListener
        isAdvertising = true
    }

    /// Configure Bonjour advertising on an existing NWListener.
    /// Call this instead of startAdvertising when the HTTPServer already has a listener.
    public func configureOnExistingListener(_ existingListener: NWListener, name: String = defaultServiceName) {
        serviceName = name
        existingListener.service = NWListener.Service(
            name: name,
            type: BonjourAdvertiser.serviceType
        )
        isAdvertising = true
    }

    /// Stop advertising the service.
    public func stopAdvertising() {
        listener?.cancel()
        listener = nil
        isAdvertising = false
    }

    // MARK: - Private

    private func handleStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            isAdvertising = true
        case .failed, .cancelled:
            isAdvertising = false
        default:
            break
        }
    }
}
#endif
