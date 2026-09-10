// HTTPRouterTests.swift
// Tests for HTTP routing, path matching, and API endpoint registration.

import Testing
import Foundation
@testable import Remote
@testable import Domain

@Suite("HTTP Router Tests")
struct HTTPRouterTests {

    @Test("Route matching — GET exact path")
    func testGetRouteMatching() async {
        let router = HTTPRouter()
        await router.get("/api/v1/status") { _ in .ok() }

        let request = HTTPRequest(method: .get, path: "/api/v1/status")
        let response = await router.handle(request)
        #expect(response.statusCode == 200)
    }

    @Test("Route matching — POST exact path")
    func testPostRouteMatching() async {
        let router = HTTPRouter()
        await router.post("/api/v1/stream/start") { _ in .ok() }

        let request = HTTPRequest(method: .post, path: "/api/v1/stream/start")
        let response = await router.handle(request)
        #expect(response.statusCode == 200)
    }

    @Test("Route matching — 404 for unknown path")
    func testUnknownPath() async {
        let router = HTTPRouter()
        await router.get("/api/v1/status") { _ in .ok() }

        let request = HTTPRequest(method: .get, path: "/api/v1/nonexistent")
        let response = await router.handle(request)
        #expect(response.statusCode == 404)
    }

    @Test("Route matching — 405 for wrong method")
    func testWrongMethod() async {
        let router = HTTPRouter()
        await router.get("/api/v1/status") { _ in .ok() }

        let request = HTTPRequest(method: .post, path: "/api/v1/status")
        let response = await router.handle(request)
        #expect(response.statusCode == 405)
    }

    @Test("CORS preflight — OPTIONS returns 204")
    func testCorsPreflightResponse() async {
        let router = HTTPRouter()
        await router.get("/api/v1/status") { _ in .ok() }

        let request = HTTPRequest(method: .options, path: "/api/v1/status")
        let response = await router.handle(request)
        #expect(response.statusCode == 204)
    }

    @Test("Middleware — intercepts request")
    func testMiddlewareIntercept() async {
        let router = HTTPRouter()
        await router.use { _ in .unauthorized("blocked") }
        await router.get("/api/v1/status") { _ in .ok() }

        let request = HTTPRequest(method: .get, path: "/api/v1/status")
        let response = await router.handle(request)
        #expect(response.statusCode == 401)
    }

    @Test("Middleware — passes through when returning nil")
    func testMiddlewarePassThrough() async {
        let router = HTTPRouter()
        await router.use { _ in nil }
        await router.get("/api/v1/status") { _ in .ok() }

        let request = HTTPRequest(method: .get, path: "/api/v1/status")
        let response = await router.handle(request)
        #expect(response.statusCode == 200)
    }
}

// MARK: - HTTP Request Tests

@Suite("HTTP Request Tests")
struct HTTPRequestTests {

    @Test("Bearer token extraction")
    func testBearerToken() {
        let request = HTTPRequest(
            method: .get,
            path: "/api/v1/status",
            headers: ["Authorization": "Bearer abc123token"]
        )
        #expect(request.bearerToken == "abc123token")
    }

    @Test("Missing bearer token returns nil")
    func testMissingBearerToken() {
        let request = HTTPRequest(method: .get, path: "/api/v1/status")
        #expect(request.bearerToken == nil)
    }

    @Test("Content-Type header")
    func testContentType() {
        let request = HTTPRequest(
            method: .post,
            path: "/api/v1/torch",
            headers: ["Content-Type": "application/json"]
        )
        #expect(request.contentType == "application/json")
    }

    @Test("Case-insensitive header lookup")
    func testCaseInsensitiveHeader() {
        let request = HTTPRequest(
            method: .get,
            path: "/test",
            headers: ["content-type": "text/html"]
        )
        #expect(request.header("Content-Type") == "text/html")
    }

    @Test("WebSocket upgrade detection")
    func testWebSocketUpgradeDetection() {
        let request = HTTPRequest(
            method: .get,
            path: "/ws",
            headers: [
                "Upgrade": "websocket",
                "Connection": "Upgrade",
                "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ==",
                "Sec-WebSocket-Version": "13"
            ]
        )
        #expect(request.isWebSocketUpgrade == true)
        #expect(request.webSocketKey == "dGhlIHNhbXBsZSBub25jZQ==")
    }

    @Test("Non-WebSocket request")
    func testNonWebSocketRequest() {
        let request = HTTPRequest(method: .get, path: "/api/v1/status")
        #expect(request.isWebSocketUpgrade == false)
    }
}

// MARK: - HTTP Response Tests

@Suite("HTTP Response Tests")
struct HTTPResponseTests {

    @Test("OK response")
    func testOkResponse() {
        let response = HTTPResponse.ok()
        #expect(response.statusCode == 200)
        #expect(response.body != nil)
    }

    @Test("Error response")
    func testErrorResponse() {
        let response = HTTPResponse.error("something broke", statusCode: 500)
        #expect(response.statusCode == 500)
    }

    @Test("Not found response")
    func testNotFoundResponse() {
        let response = HTTPResponse.notFound()
        #expect(response.statusCode == 404)
    }

    @Test("Unauthorized response")
    func testUnauthorizedResponse() {
        let response = HTTPResponse.unauthorized()
        #expect(response.statusCode == 401)
    }

    @Test("Response serialization contains HTTP line")
    func testSerialization() {
        let response = HTTPResponse.ok()
        let data = response.serialize()
        let text = String(data: data, encoding: .utf8) ?? ""
        #expect(text.contains("HTTP/1.1 200 OK"))
    }
}

// MARK: - HTTP Request Parser Tests

@Suite("HTTP Request Parser Tests")
struct HTTPRequestParserTests {

    @Test("Parse simple GET request")
    func testParseGetRequest() throws {
        let raw = "GET /api/v1/status HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let parser = HTTPRequestParser()
        let request = try parser.parse(raw.data(using: .utf8)!)
        #expect(request != nil)
        #expect(request?.method == .get)
        #expect(request?.path == "/api/v1/status")
    }

    @Test("Parse POST request with body")
    func testParsePostWithBody() throws {
        let raw = "POST /api/v1/torch HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"enabled\":true}"
        let parser = HTTPRequestParser()
        let request = try parser.parse(raw.data(using: .utf8)!)
        #expect(request != nil)
        #expect(request?.method == .post)
        #expect(request?.body != nil)
    }

    @Test("Parse query parameters")
    func testParseQueryParams() throws {
        let raw = "GET /api/v1/status?token=abc123&format=json HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let parser = HTTPRequestParser()
        let request = try parser.parse(raw.data(using: .utf8)!)
        #expect(request?.queryParameters["token"] == "abc123")
        #expect(request?.queryParameters["format"] == "json")
    }

    @Test("Incomplete request returns nil")
    func testIncompleteRequest() throws {
        let raw = "GET /api/v1/status HTTP/1.1\r\n"
        let parser = HTTPRequestParser()
        let request = try parser.parse(raw.data(using: .utf8)!)
        #expect(request == nil)
    }
}
