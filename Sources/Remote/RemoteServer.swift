// RemoteServer.swift
// Remote — Orchestrates HTTP server, WebSocket, pairing, Bonjour, and static file serving.

#if canImport(Network)
import Foundation
import Network
import Domain

/// Actor-isolated remote control server that orchestrates all Remote subsystem components.
/// Conforms to `RemoteControlling` from the Domain module.
public actor RemoteServer: RemoteControlling {

    // MARK: - Components

    private let httpServer: HTTPServer
    private let router: HTTPRouter
    private let pairingManager: PairingManager
    private let authMiddleware: AuthMiddleware
    private let bonjourAdvertiser: BonjourAdvertiser
    private let webSocketBroadcaster: WebSocketBroadcaster
    private let staticFileServer: StaticFileServer
    private let webSocketHandler: WebSocketHandler

    // MARK: - State

    private var serverState: RemoteServerState = .stopped
    private var serverPort: UInt16?

    // MARK: - Init

    /// Creates a RemoteServer with all required components.
    /// - Parameters:
    ///   - commandHandler: Bridge to camera/audio/NDI domain engines
    ///   - webAssetsBundlePath: Path to bundled web controller assets
    ///   - statusProvider: Closure providing current app state as JSON
    public init(
        commandHandler: any RemoteCommandHandling,
        webAssetsBundlePath: String,
        statusProvider: @escaping @Sendable () async -> HTTPResponse
    ) {
        let pairingMgr = PairingManager()
        let authMw = AuthMiddleware(pairingManager: pairingMgr)
        let routerInstance = HTTPRouter()
        let wsBroadcaster = WebSocketBroadcaster()
        let wsHandler = WebSocketHandler()

        self.pairingManager = pairingMgr
        self.authMiddleware = authMw
        self.router = routerInstance
        self.webSocketBroadcaster = wsBroadcaster
        self.webSocketHandler = wsHandler
        self.bonjourAdvertiser = BonjourAdvertiser()
        self.staticFileServer = StaticFileServer(bundlePath: webAssetsBundlePath)

        // HTTP server with WebSocket upgrade support
        self.httpServer = HTTPServer(
            router: routerInstance,
            webSocketUpgradeHandler: { [wsBroadcaster, wsHandler, pairingMgr] connection, request in
                // Validate token for WebSocket connections
                guard let token = request.bearerToken ?? request.queryParameters["token"],
                      await pairingMgr.validateToken(token) else {
                    connection.cancel()
                    return
                }

                // Send upgrade response
                if let upgradeData = wsHandler.upgradeResponse(for: request) {
                    connection.send(content: upgradeData, completion: .contentProcessed { _ in })
                    let _ = await wsBroadcaster.addConnection(connection, token: token)
                }
            }
        )

        // Configure routes and middleware asynchronously
        Task {
            // Register auth middleware
            let mw = await authMw.middleware()
            await routerInstance.use(mw)

            // Register API routes
            await routerInstance.registerAPIRoutes(
                commandHandler: commandHandler,
                statusProvider: statusProvider
            )

            // Register pairing endpoint (public, no auth)
            await routerInstance.post("/api/v1/pair") { [pairingMgr] request in
                guard let body = request.body,
                      let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                      let code = json["code"] as? String else {
                    return .badRequest("Missing 'code' field")
                }

                let clientInfo = RemoteClientInfo(
                    ipAddress: request.clientIP ?? "unknown",
                    userAgent: request.header("User-Agent")
                )

                do {
                    let token = try await pairingMgr.validatePairingCode(code, clientInfo: clientInfo)
                    let responsePayload: [String: Any] = [
                        "ok": true,
                        "token": token.token
                    ]
                    let data = try JSONSerialization.data(withJSONObject: responsePayload)
                    return HTTPResponse(
                        statusCode: 200,
                        statusMessage: "OK",
                        headers: [
                            "Content-Type": "application/json; charset=utf-8",
                            "Content-Length": "\(data.count)"
                        ],
                        body: data
                    )
                } catch {
                    let statusCode = (error as? PairingError) == .rateLimitExceeded ? 429 : 401
                    return .error("\(error)", statusCode: statusCode)
                }
            }

            // Register static file fallback
            // Static files are handled by checking if the path matches a file before 404
            await routerInstance.get("/") { [staticFileServer] request in
                staticFileServer.serve(path: request.path) ?? .notFound()
            }
        }
    }

    // MARK: - RemoteControlling

    public func startServer(port: UInt16) async throws {
        guard serverState == .stopped else { return }

        serverState = .starting

        do {
            try await httpServer.start(port: port)
            serverPort = await httpServer.port

            // Start Bonjour advertisement
            if let actualPort = serverPort {
                try await bonjourAdvertiser.startAdvertising(port: actualPort)
            }

            serverState = .running
        } catch {
            serverState = .error
            throw error
        }
    }

    public func stopServer() async {
        await httpServer.stop()
        await bonjourAdvertiser.stopAdvertising()
        await webSocketBroadcaster.removeAll()
        serverState = .stopped
        serverPort = nil
    }

    public func serverInfo() -> RemoteServerInfo {
        RemoteServerInfo(
            state: serverState,
            port: serverPort,
            bonjourName: BonjourAdvertiser.defaultServiceName,
            connectedClients: 0  // Updated asynchronously
        )
    }

    // MARK: - Pairing Access

    /// Generate a new pairing code for display in the app UI.
    public func generatePairingCode() async -> PairingCode {
        await pairingManager.generatePairingCode()
    }

    /// Revoke all active sessions.
    public func revokeAllSessions() async {
        await pairingManager.revokeAllTokens()
        await webSocketBroadcaster.removeAll()
    }

    /// Get the WebSocket broadcaster for state updates.
    public func broadcaster() -> WebSocketBroadcaster {
        webSocketBroadcaster
    }

    // MARK: - State Broadcasting

    /// Broadcast a state update to all connected WebSocket clients.
    public func broadcastStateUpdate(_ state: Encodable & Sendable) async {
        await webSocketBroadcaster.broadcastState(state)
    }

    /// Broadcast diagnostics to all connected WebSocket clients.
    public func broadcastDiagnosticsUpdate(_ diagnostics: Encodable & Sendable) async {
        await webSocketBroadcaster.broadcastDiagnostics(diagnostics)
    }
}
#endif
