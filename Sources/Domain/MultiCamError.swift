// MultiCamError.swift
// Domain — Strongly-typed errors for the MultiCam subsystem.

import Foundation

/// Errors produced by the MultiCam engine, capability detector, synchronizer, and compositor.
public enum MultiCamError: Error, Sendable, LocalizedError, Hashable {

    // MARK: - Hardware & Capability Errors

    /// Hardware does not support AVCaptureMultiCamSession.
    case multiCamNotSupportedOnHardware

    /// The requested operating mode is unsupported on this hardware or configuration.
    case unsupportedMode(mode: CameraMode, reason: String)

    /// The specified combination of camera devices cannot be run simultaneously.
    case unsupportedDeviceCombination(devices: [String])

    /// Aggregate hardware cost exceeded the maximum budget of 1.0.
    case hardwareCostExceeded(currentCost: Float, maximumAllowed: Float)

    // MARK: - Configuration & Slot Errors

    /// Failed to configure a specific slot.
    case slotConfigurationFailed(slot: MultiCamSlot, reason: String)

    /// The requested slot is not active or configured.
    case slotNotFound(slot: MultiCamSlot)

    /// A format does not support multi-camera capture (`isMultiCamSupported == false`).
    case formatNotMultiCamSupported(deviceID: String, formatID: String)

    // MARK: - Processing Pipeline Errors

    /// Frame composition failed.
    case compositionFailed(reason: String)

    /// Frame synchronization failed across slots.
    case synchronizationFailed(reason: String)

    /// Fallback negotiation failed to find a viable lower-tier configuration.
    case fallbackFailed(reason: String)

    // MARK: - Lifecycle Errors

    /// Attempted an operation while the session was not running.
    case sessionNotRunning

    /// Engine has not been initialized or started.
    case notInitialized

    // MARK: - Localized Descriptions

    public var errorDescription: String? {
        switch self {
        case .multiCamNotSupportedOnHardware:
            "Multi-camera capture is not supported on this device hardware."
        case .unsupportedMode(let mode, let reason):
            "Camera mode '\(mode.rawValue)' is unsupported: \(reason)"
        case .unsupportedDeviceCombination(let devices):
            "Camera device combination [\(devices.joined(separator: ", "))] is not supported simultaneously."
        case .hardwareCostExceeded(let current, let max):
            "Hardware resource cost exceeded: \(String(format: "%.2f", current)) / \(String(format: "%.2f", max)). Reduce resolution or FPS."
        case .slotConfigurationFailed(let slot, let reason):
            "Failed to configure \(slot.description): \(reason)"
        case .slotNotFound(let slot):
            "Camera slot '\(slot.rawValue)' is not currently active."
        case .formatNotMultiCamSupported(let devID, let fmtID):
            "Format '\(fmtID)' on device '\(devID)' does not support multi-camera capture."
        case .compositionFailed(let reason):
            "Multi-camera frame composition failed: \(reason)"
        case .synchronizationFailed(let reason):
            "Multi-camera frame synchronization failed: \(reason)"
        case .fallbackFailed(let reason):
            "MultiCam fallback negotiation failed: \(reason)"
        case .sessionNotRunning:
            "Multi-camera session is not currently running."
        case .notInitialized:
            "MultiCam engine has not been initialized."
        }
    }
}
