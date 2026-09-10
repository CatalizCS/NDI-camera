// PairingManager.swift
// Remote — Manages pairing codes, bearer tokens, and session lifecycle.

import Foundation
import Domain

/// Actor-isolated pairing manager.
/// Generates 6-digit pairing codes, validates attempts with rate limiting,
/// issues 256-bit random bearer tokens, and manages token revocation.
public actor PairingManager: PairingManaging {

    // MARK: - State

    private var currentCode: PairingCode?
    private var activeTokens: [String: PairingToken] = [:]  // token string → PairingToken
    private var pairingAttempts: [String: [Date]] = [:]  // IP → attempt timestamps

    /// Code expiry duration (5 minutes).
    private let codeExpirySeconds: TimeInterval = 300

    /// Max pairing attempts per IP per minute.
    private let maxAttemptsPerMinute: Int = 5

    public init() {}

    // MARK: - PairingManaging

    public func generatePairingCode() -> PairingCode {
        let digits = (0..<6).map { _ in String(Int.random(in: 0...9)) }.joined()
        let code = PairingCode(
            code: digits,
            expiresAt: Date().addingTimeInterval(codeExpirySeconds)
        )
        currentCode = code
        return code
    }

    public func validatePairingCode(_ code: String, clientInfo: RemoteClientInfo) throws -> PairingToken {
        // Rate limit check
        let ip = clientInfo.ipAddress
        cleanExpiredAttempts(for: ip)

        let recentAttempts = pairingAttempts[ip] ?? []
        guard recentAttempts.count < maxAttemptsPerMinute else {
            throw PairingError.rateLimitExceeded
        }

        // Record attempt
        pairingAttempts[ip, default: []].append(Date())

        // Validate code
        guard let currentCode, !currentCode.isExpired else {
            throw PairingError.codeExpired
        }

        guard currentCode.code == code else {
            throw PairingError.invalidCode
        }

        // Generate token (256-bit random)
        let tokenBytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        let tokenString = tokenBytes.map { String(format: "%02x", $0) }.joined()
        let tokenID = UUID().uuidString

        let token = PairingToken(
            id: tokenID,
            token: tokenString,
            issuedAt: Date(),
            clientInfo: clientInfo
        )

        activeTokens[tokenString] = token

        // Invalidate the pairing code after successful use
        self.currentCode = nil

        return token
    }

    public func validateToken(_ token: String) -> Bool {
        activeTokens[token] != nil
    }

    public func revokeToken(_ tokenID: String) {
        activeTokens = activeTokens.filter { $0.value.id != tokenID }
    }

    public func revokeAllTokens() {
        activeTokens.removeAll()
    }

    public func activeSessions() -> [PairingToken] {
        Array(activeTokens.values)
    }

    // MARK: - Current Code

    /// Returns the current pairing code, if any and not expired.
    public func currentPairingCode() -> PairingCode? {
        guard let code = currentCode, !code.isExpired else {
            return nil
        }
        return code
    }

    /// The number of active tokens.
    public var activeTokenCount: Int {
        activeTokens.count
    }

    // MARK: - Private

    private func cleanExpiredAttempts(for ip: String) {
        let cutoff = Date().addingTimeInterval(-60)  // 1-minute window
        pairingAttempts[ip] = pairingAttempts[ip]?.filter { $0 > cutoff } ?? []
    }
}

// MARK: - Pairing Error

public enum PairingError: Error, Sendable {
    case invalidCode
    case codeExpired
    case rateLimitExceeded
    case tokenNotFound
}
