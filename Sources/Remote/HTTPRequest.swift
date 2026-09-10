// HTTPRequest.swift
// Remote — Internal HTTP request model parsed from raw TCP data.

import Foundation

/// Represents an incoming HTTP request parsed from raw TCP connection data.
public struct HTTPRequest: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let queryParameters: [String: String]
    public let headers: [String: String]
    public let body: Data?

    public init(method: HTTPMethod, path: String, queryParameters: [String: String] = [:], headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.path = path
        self.queryParameters = queryParameters
        self.headers = headers
        self.body = body
    }

    /// Decode JSON body to a Decodable type.
    public func decodeBody<T: Decodable>(_ type: T.Type) throws -> T {
        guard let body else {
            throw HTTPError.missingBody
        }
        return try JSONDecoder().decode(type, from: body)
    }

    /// Returns the value of a specific header (case-insensitive).
    public func header(_ name: String) -> String? {
        let lowered = name.lowercased()
        return headers.first(where: { $0.key.lowercased() == lowered })?.value
    }

    /// The Content-Type header value, if present.
    public var contentType: String? {
        header("Content-Type")
    }

    /// The Authorization header value, if present.
    public var authorization: String? {
        header("Authorization")
    }

    /// Extracts the bearer token from the Authorization header.
    public var bearerToken: String? {
        guard let auth = authorization, auth.lowercased().hasPrefix("bearer ") else {
            return nil
        }
        return String(auth.dropFirst(7)).trimmingCharacters(in: .whitespaces)
    }

    /// The client IP address extracted from headers or connection metadata.
    public var clientIP: String? {
        header("X-Forwarded-For") ?? header("X-Real-IP")
    }
}

// MARK: - HTTP Method

public enum HTTPMethod: String, Sendable, Hashable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case options = "OPTIONS"
    case head = "HEAD"
    case patch = "PATCH"

    public init?(rawValue: String) {
        switch rawValue.uppercased() {
        case "GET": self = .get
        case "POST": self = .post
        case "PUT": self = .put
        case "DELETE": self = .delete
        case "OPTIONS": self = .options
        case "HEAD": self = .head
        case "PATCH": self = .patch
        default: return nil
        }
    }
}

// MARK: - HTTP Error

public enum HTTPError: Error, Sendable {
    case missingBody
    case invalidRequest(String)
    case parseFailed(String)
    case connectionClosed
    case timeout
}
