// HTTPRequestParser.swift
// Remote — Parses raw TCP data into HTTPRequest structs.

import Foundation

/// Parses raw HTTP/1.1 request data from NWConnection into `HTTPRequest` structs.
public struct HTTPRequestParser: Sendable {

    public init() {}

    /// Parse raw data into an HTTPRequest.
    /// Returns nil if the data does not contain a complete HTTP request.
    public func parse(_ data: Data) throws -> HTTPRequest? {
        guard let string = String(data: data, encoding: .utf8) else {
            throw HTTPError.parseFailed("Unable to decode data as UTF-8")
        }

        // Split headers from body by double CRLF
        let headerBodySplit = string.components(separatedBy: "\r\n\r\n")
        guard let headerSection = headerBodySplit.first, !headerSection.isEmpty else {
            return nil // Incomplete request
        }

        var lines = headerSection.components(separatedBy: "\r\n")
        guard !lines.isEmpty else {
            return nil
        }

        // Parse request line: METHOD /path HTTP/1.1
        let requestLine = lines.removeFirst()
        let requestParts = requestLine.split(separator: " ", maxSplits: 2)
        guard requestParts.count >= 2 else {
            throw HTTPError.parseFailed("Invalid request line: \(requestLine)")
        }

        guard let method = HTTPMethod(rawValue: String(requestParts[0])) else {
            throw HTTPError.parseFailed("Unknown HTTP method: \(requestParts[0])")
        }

        let fullPath = String(requestParts[1])

        // Parse path and query parameters
        let (path, queryParameters) = parsePathAndQuery(fullPath)

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        // Parse body
        var body: Data? = nil
        if headerBodySplit.count > 1 {
            let bodyString = headerBodySplit.dropFirst().joined(separator: "\r\n\r\n")
            if !bodyString.isEmpty {
                body = bodyString.data(using: .utf8)
            }
        }

        return HTTPRequest(
            method: method,
            path: path,
            queryParameters: queryParameters,
            headers: headers,
            body: body
        )
    }

    /// Check if the raw data contains a complete HTTP request (has the header terminator).
    public func isComplete(_ data: Data) -> Bool {
        guard let string = String(data: data, encoding: .utf8) else {
            return false
        }
        return string.contains("\r\n\r\n")
    }

    // MARK: - Private Helpers

    private func parsePathAndQuery(_ fullPath: String) -> (path: String, query: [String: String]) {
        let components = fullPath.split(separator: "?", maxSplits: 1)
        let path = String(components[0])

        var queryParams: [String: String] = [:]
        if components.count > 1 {
            let queryString = String(components[1])
            let pairs = queryString.split(separator: "&")
            for pair in pairs {
                let kv = pair.split(separator: "=", maxSplits: 1)
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                let value = kv.count > 1 ? (String(kv[1]).removingPercentEncoding ?? String(kv[1])) : ""
                queryParams[key] = value
            }
        }

        return (path, queryParams)
    }
}

// MARK: - WebSocket Upgrade Detection

extension HTTPRequest {
    /// Returns true if this request is a WebSocket upgrade request.
    public var isWebSocketUpgrade: Bool {
        let upgrade = header("Upgrade")?.lowercased()
        let connection = header("Connection")?.lowercased()
        return upgrade == "websocket" && connection?.contains("upgrade") == true
    }

    /// The Sec-WebSocket-Key header for WebSocket handshake.
    public var webSocketKey: String? {
        header("Sec-WebSocket-Key")
    }

    /// The Sec-WebSocket-Version header.
    public var webSocketVersion: String? {
        header("Sec-WebSocket-Version")
    }
}
