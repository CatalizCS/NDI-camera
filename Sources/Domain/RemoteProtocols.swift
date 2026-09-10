// RemoteProtocols.swift
// Domain — Protocol boundaries for the remote control subsystem.

import Foundation

// MARK: - Remote Controlling

/// Controls the remote server lifecycle and status.
public protocol RemoteControlling: Sendable {
    /// Starts the remote server on the specified port (0 for auto-assign).
    func startServer(port: UInt16) async throws

    /// Stops the remote server and disconnects all clients.
    func stopServer() async

    /// Returns current server info.
    func serverInfo() async -> RemoteServerInfo
}

// MARK: - Pairing Managing

/// Manages pairing codes, bearer tokens, and session lifecycle.
public protocol PairingManaging: Sendable {
    /// Generates a new 6-digit pairing code with 5-minute expiry.
    func generatePairingCode() async -> PairingCode

    /// Validates a pairing attempt and returns a token if successful.
    func validatePairingCode(_ code: String, clientInfo: RemoteClientInfo) async throws -> PairingToken

    /// Validates a bearer token. Returns true if the token is valid.
    func validateToken(_ token: String) async -> Bool

    /// Revokes a specific token.
    func revokeToken(_ tokenID: String) async

    /// Revokes all active tokens and disconnects all sessions.
    func revokeAllTokens() async

    /// Lists all active sessions/tokens (without exposing token values).
    func activeSessions() async -> [PairingToken]
}

// MARK: - Remote Command Handling

/// Bridge protocol between Remote server and domain engines (Camera, Audio, NDI).
/// The app layer provides an implementation that delegates to the actual engines.
public protocol RemoteCommandHandling: Sendable {
    /// Execute a remote command and return the result.
    func execute(_ command: RemoteCommand) async -> RemoteCommandResult
}
