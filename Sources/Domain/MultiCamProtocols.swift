// MultiCamProtocols.swift
// Domain — Protocol boundaries for the MultiCam subsystem.
// Decouples multi-camera capture management from AVFoundation specifics.

import Foundation

// MARK: - MultiCam Controlling

/// Controls a multi-camera capture session: mode transitions, slot assignments, and composite layout.
public protocol MultiCamControlling: Sendable {

    /// Start the multi-camera capture session.
    func startSession() async throws

    /// Stop the multi-camera capture session and release all device locks and hardware resources.
    func stopSession() async

    /// Change the active operating mode (e.g. single, dualIndependent, dualComposite, tripleIndependent, tripleComposite).
    func setMode(_ mode: CameraMode) async throws

    /// Assign a specific camera device and optional capture format to a slot.
    func configureSlot(_ slot: MultiCamSlot, device: CameraDevice, format: CaptureFormat?) async throws

    /// Remove a camera from a slot.
    func removeSlot(_ slot: MultiCamSlot) async throws

    /// Configure the visual composition layout when in a composite mode.
    func setCompositeLayout(_ layout: CompositeLayout) async throws

    /// Set the target frame rate across all active camera slots.
    func setTargetFPS(_ fps: Double) async throws
}

// MARK: - MultiCam Capability Providing

/// Queries dynamic multi-camera hardware capabilities and state.
public protocol MultiCamCapabilityProviding: Sendable {

    /// Returns whether the underlying hardware supports simultaneous multi-camera capture.
    func isMultiCamSupported() async -> Bool

    /// Discovers all validated physical multi-camera device combinations supported on this device.
    func availableMultiCamCombinations() async -> [MultiCamDeviceCombination]

    /// Filters supported combinations that satisfy the required camera count for a given mode.
    func supportedCombinations(for mode: CameraMode) async -> [MultiCamDeviceCombination]

    /// Returns the current MultiCam state snapshot.
    func currentState() async -> MultiCamState

    /// Returns the currently consumed hardware cost score (0.0 to 1.0).
    func currentHardwareCost() async -> Float
}
