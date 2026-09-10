// HTTPServer.swift
// Remote — Actor-isolated HTTP server using Network.framework (NWListener + NWConnection).

#if canImport(Network)
import Foundation
import Network

/// Actor-isolated HTTP/WebSocket server built on Network.framework.
/// Binds to LAN interfaces by default with configurable port.
public actor HTTPServer {

    // MARK: - State

    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private let parser = HTTPRequestParser()
    private let router: HTTPRouter
    private let webSocketUpgradeHandler: (@Sendable (NWConnection, HTTPRequest) async -> Void)?

    private(set) public var port: UInt16?
    private(set) public var isRunning: Bool = false

    private let stateQueue = DispatchQueue(label: "com.tamandicam.httpserver.state", qos: .userInitiated)
    private let connectionQueue = DispatchQueue(label: "com.tamandicam.httpserver.connection", qos: .userInitiated)

    // MARK: - Init

    /// Creates an HTTP server.
    /// - Parameters:
    ///   - router: The HTTP router for handling requests
    ///   - webSocketUpgradeHandler: Optional handler for WebSocket upgrade requests
    public init(router: HTTPRouter, webSocketUpgradeHandler: (@Sendable (NWConnection, HTTPRequest) async -> Void)? = nil) {
        self.router = router
        self.webSocketUpgradeHandler = webSocketUpgradeHandler
    }

    // MARK: - Lifecycle

    /// Start the HTTP server on the specified port.
    /// - Parameter port: Port to listen on. Pass 0 for auto-assignment.
    public func start(port: UInt16 = 0) throws {
        guard !isRunning else { return }

        let parameters = NWParameters.tcp
        // Bind to LAN only — no public interfaces
        parameters.requiredInterfaceType = .wifi

        let nwPort: NWEndpoint.Port = port == 0 ? .any : NWEndpoint.Port(rawValue: port) ?? .any
        let newListener = try NWListener(using: parameters, on: nwPort)

        newListener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task {
                await self.handleListenerStateChange(state)
            }
        }

        newListener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            Task {
                await self.handleNewConnection(connection)
            }
        }

        newListener.start(queue: stateQueue)
        listener = newListener
        isRunning = true
    }

    /// Stop the HTTP server and disconnect all clients.
    public func stop() {
        guard isRunning else { return }

        listener?.cancel()
        listener = nil

        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()

        isRunning = false
        port = nil
    }

    /// The number of active connections.
    public var connectionCount: Int {
        connections.count
    }

    // MARK: - Listener State

    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            if let listenerPort = listener?.port?.rawValue {
                port = listenerPort
            }
        case .failed:
            isRunning = false
        case .cancelled:
            isRunning = false
        default:
            break
        }
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections[id] = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task {
                await self.handleConnectionStateChange(id: id, state: state)
            }
        }

        connection.start(queue: connectionQueue)
        receiveData(on: connection, id: id)
    }

    private func handleConnectionStateChange(id: ObjectIdentifier, state: NWConnection.State) {
        switch state {
        case .failed, .cancelled:
            connections.removeValue(forKey: id)
        default:
            break
        }
    }

    private nonisolated func receiveData(on connection: NWConnection, id: ObjectIdentifier) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            Task {
                if let data, !data.isEmpty {
                    await self.processReceivedData(data, connection: connection, id: id)
                }

                if isComplete || error != nil {
                    await self.removeConnection(id: id)
                    connection.cancel()
                } else {
                    // Continue receiving
                    self.receiveData(on: connection, id: id)
                }
            }
        }
    }

    private func processReceivedData(_ data: Data, connection: NWConnection, id: ObjectIdentifier) async {
        do {
            guard let request = try parser.parse(data) else { return }

            // Check for WebSocket upgrade
            if request.isWebSocketUpgrade, let upgradeHandler = webSocketUpgradeHandler {
                await upgradeHandler(connection, request)
                return
            }

            // Route the request
            let response = await router.handle(request)
            sendResponse(response, on: connection)
        } catch {
            let response = HTTPResponse.badRequest("Failed to parse request: \(error.localizedDescription)")
            sendResponse(response, on: connection)
        }
    }

    private nonisolated func sendResponse(_ response: HTTPResponse, on connection: NWConnection) {
        let data = response.serialize()
        connection.send(content: data, completion: .contentProcessed { error in
            if let error {
                // Log but don't crash — network errors are expected
                _ = error
            }
        })
    }

    private func removeConnection(id: ObjectIdentifier) {
        connections.removeValue(forKey: id)
    }
}
#endif
