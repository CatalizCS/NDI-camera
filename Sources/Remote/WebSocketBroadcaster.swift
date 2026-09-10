// WebSocketBroadcaster.swift
// Remote — Manages active WebSocket connections and broadcasts state events.

#if canImport(Network)
import Foundation
import Network

/// Manages active WebSocket connections and broadcasts state change events.
/// Enforces max 3 connections per token.
public actor WebSocketBroadcaster {

    // MARK: - Types

    /// A tracked WebSocket connection.
    private struct TrackedConnection: Sendable {
        let connection: NWConnection
        let token: String
        let connectedAt: Date
    }

    // MARK: - State

    private var connections: [ObjectIdentifier: TrackedConnection] = [:]
    private let handler = WebSocketHandler()
    private let maxConnectionsPerToken = 3

    public init() {}

    // MARK: - Connection Management

    /// Register a new WebSocket connection.
    /// Returns false if the token already has max connections.
    public func addConnection(_ connection: NWConnection, token: String) -> Bool {
        let tokenCount = connections.values.filter { $0.token == token }.count
        guard tokenCount < maxConnectionsPerToken else {
            return false
        }

        let id = ObjectIdentifier(connection)
        connections[id] = TrackedConnection(connection: connection, token: token, connectedAt: Date())
        return true
    }

    /// Remove a WebSocket connection.
    public func removeConnection(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections.removeValue(forKey: id)
    }

    /// Remove all connections for a specific token.
    public func removeConnections(for token: String) {
        let toRemove = connections.filter { $0.value.token == token }
        for (id, tracked) in toRemove {
            tracked.connection.cancel()
            connections.removeValue(forKey: id)
        }
    }

    /// Remove all connections and cancel them.
    public func removeAll() {
        for (_, tracked) in connections {
            tracked.connection.cancel()
        }
        connections.removeAll()
    }

    /// The number of active WebSocket connections.
    public var connectionCount: Int {
        connections.count
    }

    // MARK: - Broadcasting

    /// Broadcast a state event to all connected WebSocket clients.
    public func broadcastState(_ state: Encodable & Sendable) {
        let payload: [String: Any] = ["type": "state", "payload": state]
        broadcastJSON(payload)
    }

    /// Broadcast a diagnostics event to all connected clients.
    public func broadcastDiagnostics(_ diagnostics: Encodable & Sendable) {
        let payload: [String: Any] = ["type": "diagnostics", "payload": diagnostics]
        broadcastJSON(payload)
    }

    /// Broadcast a JSON-encodable message to all clients.
    public func broadcastJSON(_ jsonObject: Any) {
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        broadcastText(text)
    }

    /// Broadcast raw text to all connected WebSocket clients.
    public func broadcastText(_ text: String) {
        let frame = WebSocketFrame.text(text)
        let frameData = handler.encode(frame)

        for (id, tracked) in connections {
            tracked.connection.send(content: frameData, completion: .contentProcessed { [weak self] error in
                if error != nil {
                    Task { [weak self] in
                        await self?.removeConnection(id: id)
                    }
                }
            })
        }
    }

    /// Send a ping to all connections for keep-alive.
    public func pingAll() {
        let frame = WebSocketFrame(opcode: .ping, payload: Data())
        let frameData = handler.encode(frame)

        for (_, tracked) in connections {
            tracked.connection.send(content: frameData, completion: .contentProcessed { _ in })
        }
    }

    // MARK: - Private

    private func removeConnection(id: ObjectIdentifier) {
        connections.removeValue(forKey: id)
    }
}
#endif
