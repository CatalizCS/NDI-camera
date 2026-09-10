// RemoteTypesTests.swift

import Testing
@testable import Domain

@Suite("Remote Types Tests")
struct RemoteTypesTests {

    @Test("RemoteCommandResult success")
    func testSuccessResult() {
        let result = RemoteCommandResult.success()
        #expect(result.ok == true)
        #expect(result.error == nil)
    }

    @Test("RemoteCommandResult failure")
    func testFailureResult() {
        let result = RemoteCommandResult.failure("not found")
        #expect(result.ok == false)
        #expect(result.error == "not found")
    }

    @Test("PairingCode expiry check")
    func testPairingCodeExpiry() {
        let expired = PairingCode(code: "123456", expiresAt: Date.distantPast)
        #expect(expired.isExpired == true)

        let valid = PairingCode(code: "654321", expiresAt: Date.distantFuture)
        #expect(valid.isExpired == false)
    }

    @Test("PairingToken identifiable")
    func testPairingToken() {
        let token = PairingToken(
            id: "tok-1",
            token: "abc123",
            issuedAt: Date(),
            clientInfo: RemoteClientInfo(ipAddress: "192.168.1.10")
        )
        #expect(token.id == "tok-1")
    }

    @Test("RemoteCommandResult Codable roundtrip")
    func testCommandResultCodable() throws {
        let original = RemoteCommandResult.failure("timeout")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RemoteCommandResult.self, from: data)
        #expect(decoded == original)
    }

    @Test("RemoteServerInfo defaults")
    func testServerInfoDefaults() {
        let info = RemoteServerInfo(state: .stopped)
        #expect(info.port == nil)
        #expect(info.bonjourName == nil)
        #expect(info.connectedClients == 0)
    }
}
