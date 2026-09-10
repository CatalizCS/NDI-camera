// PairingManagerTests.swift
// Tests for pairing code generation, validation, rate limiting, and token lifecycle.

import Testing
import Foundation
@testable import Remote
@testable import Domain

@Suite("Pairing Manager Tests")
struct PairingManagerTests {

    @Test("Generate pairing code — 6 digits")
    func testGeneratePairingCode() async {
        let manager = PairingManager()
        let code = await manager.generatePairingCode()
        #expect(code.code.count == 6)
        #expect(code.code.allSatisfy { $0.isNumber })
        #expect(code.isExpired == false)
    }

    @Test("Validate correct code — returns token")
    func testValidateCorrectCode() async throws {
        let manager = PairingManager()
        let code = await manager.generatePairingCode()
        let clientInfo = RemoteClientInfo(ipAddress: "192.168.1.10")
        let token = try await manager.validatePairingCode(code.code, clientInfo: clientInfo)
        #expect(!token.token.isEmpty)
        #expect(token.token.count == 64) // 32 bytes = 64 hex chars
        #expect(token.clientInfo.ipAddress == "192.168.1.10")
    }

    @Test("Validate wrong code — throws invalidCode")
    func testValidateWrongCode() async {
        let manager = PairingManager()
        let _ = await manager.generatePairingCode()
        let clientInfo = RemoteClientInfo(ipAddress: "192.168.1.10")

        do {
            let _ = try await manager.validatePairingCode("000000", clientInfo: clientInfo)
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is PairingError)
        }
    }

    @Test("Code expires after use")
    func testCodeExpiresAfterUse() async throws {
        let manager = PairingManager()
        let code = await manager.generatePairingCode()
        let clientInfo = RemoteClientInfo(ipAddress: "192.168.1.10")

        // First use succeeds
        let _ = try await manager.validatePairingCode(code.code, clientInfo: clientInfo)

        // Second use fails (code invalidated)
        do {
            let _ = try await manager.validatePairingCode(code.code, clientInfo: clientInfo)
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is PairingError)
        }
    }

    @Test("Token validation — valid token returns true")
    func testTokenValidation() async throws {
        let manager = PairingManager()
        let code = await manager.generatePairingCode()
        let clientInfo = RemoteClientInfo(ipAddress: "192.168.1.10")
        let token = try await manager.validatePairingCode(code.code, clientInfo: clientInfo)

        let isValid = await manager.validateToken(token.token)
        #expect(isValid == true)
    }

    @Test("Token validation — invalid token returns false")
    func testInvalidTokenValidation() async {
        let manager = PairingManager()
        let isValid = await manager.validateToken("nonexistent-token")
        #expect(isValid == false)
    }

    @Test("Revoke specific token")
    func testRevokeToken() async throws {
        let manager = PairingManager()
        let code = await manager.generatePairingCode()
        let clientInfo = RemoteClientInfo(ipAddress: "192.168.1.10")
        let token = try await manager.validatePairingCode(code.code, clientInfo: clientInfo)

        await manager.revokeToken(token.id)

        let isValid = await manager.validateToken(token.token)
        #expect(isValid == false)
    }

    @Test("Revoke all tokens")
    func testRevokeAllTokens() async throws {
        let manager = PairingManager()

        // Create multiple tokens
        let code1 = await manager.generatePairingCode()
        let token1 = try await manager.validatePairingCode(code1.code, clientInfo: RemoteClientInfo(ipAddress: "192.168.1.10"))

        let code2 = await manager.generatePairingCode()
        let token2 = try await manager.validatePairingCode(code2.code, clientInfo: RemoteClientInfo(ipAddress: "192.168.1.11"))

        await manager.revokeAllTokens()

        let isValid1 = await manager.validateToken(token1.token)
        let isValid2 = await manager.validateToken(token2.token)
        #expect(isValid1 == false)
        #expect(isValid2 == false)
    }

    @Test("Active sessions list")
    func testActiveSessions() async throws {
        let manager = PairingManager()
        let code = await manager.generatePairingCode()
        let clientInfo = RemoteClientInfo(ipAddress: "192.168.1.10", userAgent: "Safari")
        let _ = try await manager.validatePairingCode(code.code, clientInfo: clientInfo)

        let sessions = await manager.activeSessions()
        #expect(sessions.count == 1)
        #expect(sessions.first?.clientInfo.userAgent == "Safari")
    }

    @Test("Rate limiting — blocks after 5 attempts")
    func testRateLimiting() async {
        let manager = PairingManager()
        let clientInfo = RemoteClientInfo(ipAddress: "192.168.1.10")

        // Make 5 failed attempts
        for _ in 0..<5 {
            let _ = await manager.generatePairingCode()
            do {
                let _ = try await manager.validatePairingCode("000000", clientInfo: clientInfo)
            } catch {
                // Expected
            }
        }

        // 6th attempt should be rate limited
        let _ = await manager.generatePairingCode()
        do {
            let _ = try await manager.validatePairingCode("000000", clientInfo: clientInfo)
            #expect(Bool(false), "Should have been rate limited")
        } catch let error as PairingError {
            #expect(error == .rateLimitExceeded)
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
}

// Make PairingError equatable for test assertions
extension PairingError: Equatable {}
