// HTTPResponse.swift
// Remote — HTTP response model and builder.

import Foundation

/// Represents an outgoing HTTP response to be serialized and sent via NWConnection.
public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let statusMessage: String
    public let headers: [String: String]
    public let body: Data?

    public init(statusCode: Int, statusMessage: String, headers: [String: String] = [:], body: Data? = nil) {
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.headers = headers
        self.body = body
    }

    // MARK: - Convenience Factories

    /// 200 OK with JSON body.
    public static func json<T: Encodable>(_ value: T, statusCode: Int = 200) throws -> HTTPResponse {
        let data = try JSONEncoder().encode(value)
        return HTTPResponse(
            statusCode: statusCode,
            statusMessage: statusText(for: statusCode),
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Content-Length": "\(data.count)"
            ],
            body: data
        )
    }

    /// 200 OK with a simple { ok: true } JSON response.
    public static func ok() -> HTTPResponse {
        let body = #"{"ok":true}"#.data(using: .utf8)!
        return HTTPResponse(
            statusCode: 200,
            statusMessage: "OK",
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Content-Length": "\(body.count)"
            ],
            body: body
        )
    }

    /// Error response with { ok: false, error: "message" }.
    public static func error(_ message: String, statusCode: Int = 500) -> HTTPResponse {
        let payload: [String: Any] = ["ok": false, "error": message]
        let body = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        return HTTPResponse(
            statusCode: statusCode,
            statusMessage: statusText(for: statusCode),
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Content-Length": "\(body.count)"
            ],
            body: body
        )
    }

    /// 400 Bad Request.
    public static func badRequest(_ message: String = "Bad Request") -> HTTPResponse {
        error(message, statusCode: 400)
    }

    /// 401 Unauthorized.
    public static func unauthorized(_ message: String = "Unauthorized") -> HTTPResponse {
        error(message, statusCode: 401)
    }

    /// 404 Not Found.
    public static func notFound(_ message: String = "Not Found") -> HTTPResponse {
        error(message, statusCode: 404)
    }

    /// 405 Method Not Allowed.
    public static func methodNotAllowed() -> HTTPResponse {
        error("Method Not Allowed", statusCode: 405)
    }

    /// 429 Too Many Requests.
    public static func tooManyRequests(_ message: String = "Too Many Requests") -> HTTPResponse {
        error(message, statusCode: 429)
    }

    /// Serve a static file with appropriate content type.
    public static func file(data: Data, contentType: String, cacheControl: String? = nil) -> HTTPResponse {
        var headers: [String: String] = [
            "Content-Type": contentType,
            "Content-Length": "\(data.count)"
        ]
        if let cacheControl {
            headers["Cache-Control"] = cacheControl
        }
        return HTTPResponse(
            statusCode: 200,
            statusMessage: "OK",
            headers: headers,
            body: data
        )
    }

    // MARK: - Serialization

    /// Serialize to raw HTTP response bytes.
    public func serialize() -> Data {
        var response = "HTTP/1.1 \(statusCode) \(statusMessage)\r\n"
        for (key, value) in headers {
            response += "\(key): \(value)\r\n"
        }
        // Add CORS headers for browser compatibility
        if headers["Access-Control-Allow-Origin"] == nil {
            response += "Access-Control-Allow-Origin: *\r\n"
        }
        response += "Connection: keep-alive\r\n"
        response += "\r\n"

        var data = response.data(using: .utf8) ?? Data()
        if let body {
            data.append(body)
        }
        return data
    }

    // MARK: - Status Text Mapping

    private static func statusText(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 301: return "Moved Permanently"
        case 304: return "Not Modified"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 503: return "Service Unavailable"
        default: return "Unknown"
        }
    }
}
