// RemoteTypes.swift
// Domain — Types for the remote control subsystem.

import Foundation

// MARK: - Remote Command

/// Represents all possible commands from a remote controller.
public enum RemoteCommand: Sendable, Codable, Hashable {
    case selectCamera(deviceID: String)
    case setZoom(factor: Double)
    case setFocus(mode: String, x: Double?, y: Double?)
    case setExposure(mode: String, x: Double?, y: Double?)
    case setExposureCompensation(ev: Float)
    case setTorch(enabled: Bool, level: Float?)
    case setVideo(resolution: String?, fps: Double?, stabilization: String?)
    case setAudio(muted: Bool?, gain: Float?, deviceID: String?)
    case setOrientation(mode: String)
    case setDisplay(mode: String)
    case startStream
    case stopStream
    case loadPreset(id: String)
}

// MARK: - Remote Command Result

/// Result envelope for command execution.
public struct RemoteCommandResult: Sendable, Codable, Hashable {
    public let ok: Bool
    public let error: String?

    public init(ok: Bool, error: String? = nil) {
        self.ok = ok
        self.error = error
    }

    public static func success() -> RemoteCommandResult {
        RemoteCommandResult(ok: true)
    }

    public static func failure(_ error: String) -> RemoteCommandResult {
        RemoteCommandResult(ok: false, error: error)
    }
}

// MARK: - Pairing

/// A 6-digit pairing code displayed to the user.
public struct PairingCode: Sendable, Hashable {
    public let code: String
    public let expiresAt: Date

    public init(code: String, expiresAt: Date) {
        self.code = code
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool {
        Date() >= expiresAt
    }
}

/// A bearer token issued after successful pairing.
public struct PairingToken: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let token: String
    public let issuedAt: Date
    public let clientInfo: RemoteClientInfo

    public init(id: String, token: String, issuedAt: Date, clientInfo: RemoteClientInfo) {
        self.id = id
        self.token = token
        self.issuedAt = issuedAt
        self.clientInfo = clientInfo
    }
}

/// Metadata about a connected remote client.
public struct RemoteClientInfo: Sendable, Hashable, Codable {
    public let ipAddress: String
    public let userAgent: String?

    public init(ipAddress: String, userAgent: String? = nil) {
        self.ipAddress = ipAddress
        self.userAgent = userAgent
    }
}

// MARK: - Remote Server State

/// The state of the remote control server.
public enum RemoteServerState: String, Sendable, Codable, Hashable {
    case stopped
    case starting
    case running
    case error
}

/// Information about the running remote server.
public struct RemoteServerInfo: Sendable, Hashable {
    public let state: RemoteServerState
    public let port: UInt16?
    public let bonjourName: String?
    public let connectedClients: Int

    public init(state: RemoteServerState, port: UInt16? = nil, bonjourName: String? = nil, connectedClients: Int = 0) {
        self.state = state
        self.port = port
        self.bonjourName = bonjourName
        self.connectedClients = connectedClients
    }
}
