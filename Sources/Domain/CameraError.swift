// CameraError.swift
// Domain — Error types for the camera subsystem.

import Foundation

/// Errors produced by the camera engine.
public enum CameraError: Error, Sendable, LocalizedError, Hashable {

    // MARK: - Device Errors

    /// The requested camera device was not found on this hardware.
    case deviceNotFound(deviceID: String)

    /// Failed to create a capture device input.
    case inputCreationFailed(reason: String)

    /// The device does not support the requested configuration.
    case deviceConfigurationFailed(reason: String)

    // MARK: - Format Errors

    /// No format matches the requested resolution and FPS.
    case formatNotAvailable(width: Int, height: Int, fps: Double)

    /// The requested FPS is not supported by any format on this device.
    case fpsNotSupported(requested: Double, maxAvailable: Double)

    // MARK: - Session Errors

    /// The capture session could not be configured.
    case sessionConfigurationFailed(reason: String)

    /// The session was interrupted (e.g., phone call, multitasking).
    case sessionInterrupted(reason: String)

    /// The session is not currently running.
    case sessionNotRunning

    // MARK: - Control Errors

    /// Torch is not available on this device or in this configuration.
    case torchNotAvailable

    /// The requested stabilization mode is not supported by the current format.
    case stabilizationNotSupported(mode: StabilizationMode)

    /// Focus mode is not supported by this device.
    case focusModeNotSupported(mode: FocusMode)

    /// Exposure mode is not supported by this device.
    case exposureModeNotSupported(mode: ExposureMode)

    /// The requested zoom factor is out of range.
    case zoomOutOfRange(requested: Double, min: Double, max: Double)

    /// Exposure compensation value is out of range.
    case exposureCompensationOutOfRange(requested: Float, min: Float, max: Float)

    // MARK: - Permission Errors

    /// Camera access was not authorized by the user.
    case cameraPermissionDenied

    /// Camera access is restricted by system policy.
    case cameraPermissionRestricted

    // MARK: - Lifecycle

    /// A required operation was attempted before the engine was started.
    case notInitialized

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound(let id):
            "Camera device not found: \(id)"
        case .inputCreationFailed(let reason):
            "Failed to create camera input: \(reason)"
        case .deviceConfigurationFailed(let reason):
            "Device configuration failed: \(reason)"
        case .formatNotAvailable(let w, let h, let fps):
            "No format available for \(w)×\(h) @ \(fps) FPS"
        case .fpsNotSupported(let requested, let max):
            "FPS \(requested) not supported (max: \(max))"
        case .sessionConfigurationFailed(let reason):
            "Session configuration failed: \(reason)"
        case .sessionInterrupted(let reason):
            "Session interrupted: \(reason)"
        case .sessionNotRunning:
            "Camera session is not running"
        case .torchNotAvailable:
            "Torch is not available on this device"
        case .stabilizationNotSupported(let mode):
            "Stabilization mode '\(mode.displayName)' is not supported by the current format"
        case .focusModeNotSupported(let mode):
            "Focus mode '\(mode.displayName)' is not supported"
        case .exposureModeNotSupported(let mode):
            "Exposure mode '\(mode.displayName)' is not supported"
        case .zoomOutOfRange(let req, let min, let max):
            "Zoom factor \(req) is out of range (\(min)–\(max))"
        case .exposureCompensationOutOfRange(let req, let min, let max):
            "Exposure compensation \(req) is out of range (\(min)–\(max))"
        case .cameraPermissionDenied:
            "Camera access denied. Enable in Settings → Privacy → Camera."
        case .cameraPermissionRestricted:
            "Camera access is restricted by system policy."
        case .notInitialized:
            "Camera engine has not been initialized."
        }
    }
}
