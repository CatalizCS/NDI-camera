// CameraTypes.swift
// Domain — Shared camera-related enumerations and small value types.

import Foundation

// MARK: - Video Orientation

/// NDI/capture output orientation. Independent of the UI orientation.
public enum VideoOrientation: String, Sendable, Codable, CaseIterable, Hashable {
    case auto
    case portrait
    case landscapeLeft
    case landscapeRight
}

// MARK: - Stabilization Mode

/// Video stabilization mode. Availability is discovered dynamically per format.
public enum StabilizationMode: String, Sendable, Codable, CaseIterable, Hashable {
    case off
    case standard
    case cinematic
    case cinematicExtended
    case auto

    /// Human-readable label for UI display.
    public var displayName: String {
        switch self {
        case .off: "Off"
        case .standard: "Standard"
        case .cinematic: "Cinematic"
        case .cinematicExtended: "Cinematic Extended"
        case .auto: "Auto"
        }
    }
}

// MARK: - Focus Mode

/// Focus control mode.
public enum FocusMode: String, Sendable, Codable, CaseIterable, Hashable {
    case locked
    case autoFocus
    case continuousAutoFocus

    public var displayName: String {
        switch self {
        case .locked: "Locked"
        case .autoFocus: "Auto Focus"
        case .continuousAutoFocus: "Continuous"
        }
    }
}

// MARK: - Exposure Mode

/// Exposure control mode.
public enum ExposureMode: String, Sendable, Codable, CaseIterable, Hashable {
    case locked
    case autoExpose
    case continuousAutoExposure
    case custom

    public var displayName: String {
        switch self {
        case .locked: "Locked"
        case .autoExpose: "Auto"
        case .continuousAutoExposure: "Continuous"
        case .custom: "Custom"
        }
    }
}

// MARK: - Display Mode

/// On-device preview display mode. Capture continues in all modes.
public enum DisplayMode: String, Sendable, Codable, CaseIterable, Hashable {
    /// Normal preview brightness.
    case normal
    /// Reduced brightness to conserve battery.
    case dimmed
    /// Preview blacked out — capture still runs in foreground.
    case blacked
}

// MARK: - Camera Mode

/// Multi-camera output configuration.
public enum CameraMode: String, Sendable, Codable, CaseIterable, Hashable {
    case single
    case dualIndependent
    case dualComposite
    case tripleIndependent
    case tripleComposite

    /// Number of physical cameras required.
    public var cameraCount: Int {
        switch self {
        case .single: 1
        case .dualIndependent, .dualComposite: 2
        case .tripleIndependent, .tripleComposite: 3
        }
    }

    /// Whether this mode requires `AVCaptureMultiCamSession`.
    public var requiresMultiCam: Bool {
        self != .single
    }
}

// MARK: - Normalized Point

/// A point in normalized coordinates (0.0 ... 1.0) for focus/exposure targeting.
/// Origin is top-left. Independent of CoreGraphics.
public struct NormalizedPoint: Sendable, Hashable, Codable {
    /// Horizontal position, 0.0 (left) to 1.0 (right).
    public let x: Double
    /// Vertical position, 0.0 (top) to 1.0 (bottom).
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }

    /// Center point.
    public static let center = NormalizedPoint(x: 0.5, y: 0.5)
}

// MARK: - Stream State

/// Lifecycle state of the camera/NDI pipeline.
public enum StreamState: String, Sendable, Codable, Hashable {
    case idle
    case starting
    case running
    case stopping
    case error
}

// MARK: - Camera Capability

/// Aggregated capability summary for the current device configuration.
public struct CameraCapability: Sendable, Hashable {
    public let devices: [CameraDevice]
    public let isMultiCamSupported: Bool
    public let supportedModes: [CameraMode]

    public init(
        devices: [CameraDevice],
        isMultiCamSupported: Bool,
        supportedModes: [CameraMode]
    ) {
        self.devices = devices
        self.isMultiCamSupported = isMultiCamSupported
        self.supportedModes = supportedModes
    }
}

// MARK: - Torch Level

/// Torch intensity configuration.
public struct TorchConfiguration: Sendable, Hashable, Codable {
    /// Whether the torch is enabled.
    public let isEnabled: Bool
    /// Intensity level from 0.0 to 1.0. `nil` means use default (max) level.
    public let level: Float?

    public init(isEnabled: Bool, level: Float? = nil) {
        self.isEnabled = isEnabled
        self.level = level.map { min(max($0, 0), 1) }
    }

    public static let off = TorchConfiguration(isEnabled: false)
    public static let on = TorchConfiguration(isEnabled: true)
}
