// AuthMiddleware.swift
// Remote — Bearer token authentication and rate limiting middleware.

import Foundation

/// Authentication and rate limiting middleware for the HTTP router.
/// Extracts Bearer tokens, validates against PairingManager, and enforces rate limits.
public actor AuthMiddleware {

    // MARK: - State

    private let pairingManager: PairingManager
    private var commandCounts: [String: [Date]] = [:]  // token → timestamps
    private var queryCounts: [String: [Date]] = [:]     // token → timestamps

    /// Rate limits per token.
    private let maxCommandsPerSecond: Int = 30
    private let maxQueriesPerSecond: Int = 60

    /// Paths that don't require authentication.
    private let publicPaths: Set<String> = [
        "/api/v1/pair",
        "/",
        "/index.html",
        "/style.css",
        "/app.js"
    ]

    public init(pairingManager: PairingManager) {
        self.pairingManager = pairingManager
    }

    // MARK: - Middleware

    /// Returns a middleware function for the HTTP router.
    public func middleware() -> HTTPMiddleware {
        return { [weak self] request in
            guard let self else { return HTTPResponse.error("Server error", statusCode: 500) }
            return await self.authenticate(request)
        }
    }

    /// Authenticate and rate-limit a request.
    /// Returns nil to continue to the handler, or an error response to short-circuit.
    public func authenticate(_ request: HTTPRequest) async -> HTTPResponse? {
        // Skip auth for public paths and static files
        if isPublicPath(request.path) {
            return nil
        }

        // WebSocket upgrade passes through — auth checked during upgrade
        if request.isWebSocketUpgrade {
            return nil
        }

        // Extract bearer token
        guard let token = request.bearerToken else {
            return .unauthorized("Missing Authorization header")
        }

        // Validate token
        let isValid = await pairingManager.validateToken(token)
        guard isValid else {
            return .unauthorized("Invalid or revoked token")
        }

        // Rate limiting
        let isQuery = request.method == .get
        let isRateLimited = await checkRateLimit(token: token, isQuery: isQuery)
        if isRateLimited {
            return .tooManyRequests()
        }

        return nil // Authenticated, continue to handler
    }

    // MARK: - Private

    private func isPublicPath(_ path: String) -> Bool {
        // Public paths and static file extensions
        if publicPaths.contains(path) { return true }
        let ext = (path as NSString).pathExtension.lowercased()
        return ["html", "css", "js", "svg", "png", "ico", "woff", "woff2"].contains(ext)
    }

    private func checkRateLimit(token: String, isQuery: Bool) async -> Bool {
        let now = Date()
        let cutoff = now.addingTimeInterval(-1.0) // 1-second window

        if isQuery {
            queryCounts[token] = (queryCounts[token] ?? []).filter { $0 > cutoff }
            queryCounts[token, default: []].append(now)
            return (queryCounts[token]?.count ?? 0) > maxQueriesPerSecond
        } else {
            commandCounts[token] = (commandCounts[token] ?? []).filter { $0 > cutoff }
            commandCounts[token, default: []].append(now)
            return (commandCounts[token]?.count ?? 0) > maxCommandsPerSecond
        }
    }
}
