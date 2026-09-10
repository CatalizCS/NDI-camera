// HTTPRouter.swift
// Remote — Route registration with method + path matching and middleware chain.

import Foundation
import Domain

/// A handler that processes an HTTP request and returns a response.
public typealias HTTPRouteHandler = @Sendable (HTTPRequest) async -> HTTPResponse

/// Middleware that can intercept requests before they reach the handler.
/// Returns a response to short-circuit, or nil to continue to the next middleware/handler.
public typealias HTTPMiddleware = @Sendable (HTTPRequest) async -> HTTPResponse?

/// Routes incoming HTTP requests to registered handlers with middleware support.
public actor HTTPRouter {

    // MARK: - Route Registration

    private struct Route: Sendable {
        let method: HTTPMethod
        let path: String
        let handler: HTTPRouteHandler
    }

    private var routes: [Route] = []
    private var middleware: [HTTPMiddleware] = []

    public init() {}

    // MARK: - Registration

    /// Register a route handler for a specific method and path.
    public func register(_ method: HTTPMethod, _ path: String, handler: @escaping HTTPRouteHandler) {
        routes.append(Route(method: method, path: path, handler: handler))
    }

    /// Register a GET route.
    public func get(_ path: String, handler: @escaping HTTPRouteHandler) {
        register(.get, path, handler: handler)
    }

    /// Register a POST route.
    public func post(_ path: String, handler: @escaping HTTPRouteHandler) {
        register(.post, path, handler: handler)
    }

    /// Add a middleware to the chain. Middleware are executed in registration order.
    public func use(_ middlewareFn: @escaping HTTPMiddleware) {
        middleware.append(middlewareFn)
    }

    // MARK: - Request Handling

    /// Route a request through middleware and to the matching handler.
    public func handle(_ request: HTTPRequest) async -> HTTPResponse {
        // Run middleware chain
        for mw in middleware {
            if let response = await mw(request) {
                return response
            }
        }

        // Handle CORS preflight
        if request.method == .options {
            return corsPreflightResponse()
        }

        // Find matching route
        guard let route = routes.first(where: { $0.method == request.method && matchPath($0.path, against: request.path) }) else {
            // Check if the path exists but method is wrong
            if routes.contains(where: { matchPath($0.path, against: request.path) }) {
                return .methodNotAllowed()
            }
            return .notFound("No route found for \(request.method.rawValue) \(request.path)")
        }

        return await route.handler(request)
    }

    // MARK: - API Route Registration

    /// Register all TamaNDI REST API routes.
    /// The commandHandler bridges commands to the app's domain engines.
    public func registerAPIRoutes(commandHandler: any RemoteCommandHandling, statusProvider: @escaping @Sendable () async -> HTTPResponse) {
        // Status and capability queries
        get("/api/v1/status") { _ in
            await statusProvider()
        }

        get("/api/v1/capabilities") { _ in
            await statusProvider() // Capabilities included in status for now
        }

        get("/api/v1/cameras") { _ in
            await statusProvider()
        }

        get("/api/v1/formats") { _ in
            await statusProvider()
        }

        get("/api/v1/settings") { _ in
            await statusProvider()
        }

        // Stream control
        post("/api/v1/stream/start") { request in
            let result = await commandHandler.execute(.startStream)
            return result.ok ? .ok() : .error(result.error ?? "Failed to start stream", statusCode: 500)
        }

        post("/api/v1/stream/stop") { request in
            let result = await commandHandler.execute(.stopStream)
            return result.ok ? .ok() : .error(result.error ?? "Failed to stop stream", statusCode: 500)
        }

        // Camera controls
        post("/api/v1/camera/select") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let deviceID = json["camera"] as? String else {
                return .badRequest("Missing 'camera' field")
            }
            let result = await commandHandler.execute(.selectCamera(deviceID: deviceID))
            return result.ok ? .ok() : .error(result.error ?? "Failed", statusCode: 400)
        }

        post("/api/v1/camera/zoom") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let factor = json["factor"] as? Double else {
                return .badRequest("Missing 'factor' field")
            }
            let result = await commandHandler.execute(.setZoom(factor: factor))
            return result.ok ? .ok() : .error(result.error ?? "Failed", statusCode: 400)
        }

        post("/api/v1/camera/focus") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let mode = json["mode"] as? String else {
                return .badRequest("Missing 'mode' field")
            }
            let x = json["x"] as? Double
            let y = json["y"] as? Double
            let result = await commandHandler.execute(.setFocus(mode: mode, x: x, y: y))
            return result.ok ? .ok() : .error(result.error ?? "Failed", statusCode: 400)
        }

        post("/api/v1/camera/exposure") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let mode = json["mode"] as? String else {
                return .badRequest("Missing 'mode' field")
            }
            let x = json["x"] as? Double
            let y = json["y"] as? Double
            let result = await commandHandler.execute(.setExposure(mode: mode, x: x, y: y))
            return result.ok ? .ok() : .error(result.error ?? "Failed", statusCode: 400)
        }

        post("/api/v1/torch") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let enabled = json["enabled"] as? Bool else {
                return .badRequest("Missing 'enabled' field")
            }
            let level = json["level"] as? Float
            let result = await commandHandler.execute(.setTorch(enabled: enabled, level: level))
            return result.ok ? .ok() : .error(result.error ?? "Failed", statusCode: 400)
        }

        post("/api/v1/video") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                return .badRequest("Invalid JSON body")
            }
            let resolution = json["resolution"] as? String
            let fps = json["fps"] as? Double
            let stabilization = json["stabilization"] as? String
            let result = await commandHandler.execute(.setVideo(resolution: resolution, fps: fps, stabilization: stabilization))
            return result.ok ? .ok() : .error(result.error ?? "Failed", statusCode: 400)
        }

        post("/api/v1/audio") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                return .badRequest("Invalid JSON body")
            }
            let muted = json["muted"] as? Bool
            let gain = json["gain"] as? Float
            let deviceID = json["deviceID"] as? String
            let result = await commandHandler.execute(.setAudio(muted: muted, gain: gain, deviceID: deviceID))
            return result.ok ? .ok() : .error(result.error ?? "Failed", statusCode: 400)
        }

        post("/api/v1/orientation") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let mode = json["mode"] as? String else {
                return .badRequest("Missing 'mode' field")
            }
            let result = await commandHandler.execute(.setOrientation(mode: mode))
            return result.ok ? .ok() : .error(result.error ?? "Failed", statusCode: 400)
        }

        post("/api/v1/display") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let mode = json["mode"] as? String else {
                return .badRequest("Missing 'mode' field")
            }
            let result = await commandHandler.execute(.setDisplay(mode: mode))
            return result.ok ? .ok() : .error(result.error ?? "Failed", statusCode: 400)
        }

        post("/api/v1/preset/load") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let presetID = json["id"] as? String else {
                return .badRequest("Missing 'id' field")
            }
            let result = await commandHandler.execute(.loadPreset(id: presetID))
            return result.ok ? .ok() : .error(result.error ?? "Failed", statusCode: 400)
        }
    }

    // MARK: - Private Helpers

    private func matchPath(_ routePath: String, against requestPath: String) -> Bool {
        routePath == requestPath
    }

    private func corsPreflightResponse() -> HTTPResponse {
        HTTPResponse(
            statusCode: 204,
            statusMessage: "No Content",
            headers: [
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization",
                "Access-Control-Max-Age": "86400"
            ]
        )
    }
}
