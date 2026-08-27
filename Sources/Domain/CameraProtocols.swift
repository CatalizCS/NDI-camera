// CameraProtocols.swift
// Domain — Protocol boundaries for the camera subsystem.
// These protocols decouple the UI layer from AVFoundation implementation details.

import Foundation

// MARK: - Camera State

/// Observable snapshot of the current camera state.
/// Published by the camera engine for UI consumption.
public struct CameraState: Sendable, Hashable {
    public let selectedDevice: CameraDevice?
    public let activeFormat: CaptureFormat?
    public let targetFPS: Double
    public let currentZoomFactor: Double
    public let focusMode: FocusMode
    public let exposureMode: ExposureMode
    public let exposureCompensation: Float
    public let isTorchActive: Bool
    public let torchLevel: Float
    public let stabilizationMode: StabilizationMode
    public let videoOrientation: VideoOrientation
    public let isOrientationLocked: Bool
    public let sessionState: StreamState

    public init(
        selectedDevice: CameraDevice? = nil,
        activeFormat: CaptureFormat? = nil,
        targetFPS: Double = 30,
        currentZoomFactor: Double = 1.0,
        focusMode: FocusMode = .continuousAutoFocus,
        exposureMode: ExposureMode = .continuousAutoExposure,
        exposureCompensation: Float = 0,
        isTorchActive: Bool = false,
        torchLevel: Float = 1.0,
        stabilizationMode: StabilizationMode = .off,
        videoOrientation: VideoOrientation = .auto,
        isOrientationLocked: Bool = false,
        sessionState: StreamState = .idle
    ) {
        self.selectedDevice = selectedDevice
        self.activeFormat = activeFormat
        self.targetFPS = targetFPS
        self.currentZoomFactor = currentZoomFactor
        self.focusMode = focusMode
        self.exposureMode = exposureMode
        self.exposureCompensation = exposureCompensation
        self.isTorchActive = isTorchActive
        self.torchLevel = torchLevel
        self.stabilizationMode = stabilizationMode
        self.videoOrientation = videoOrientation
        self.isOrientationLocked = isOrientationLocked
        self.sessionState = sessionState
    }
}

// MARK: - Camera Controlling

/// Controls camera hardware: device selection, focus, exposure, zoom, torch, stabilization.
///
/// All methods are async and may throw `CameraError`.
/// Implementations must be safe to call from any actor context.
public protocol CameraControlling: Sendable {

    // MARK: Session Lifecycle

    /// Start the capture session. Must be called before any other control methods.
    func startSession() async throws

    /// Stop the capture session and release resources.
    func stopSession() async

    // MARK: Device Selection

    /// Select a camera device by its descriptor.
    func selectCamera(_ device: CameraDevice) async throws

    // MARK: Format and FPS

    /// Apply a specific capture format.
    func setFormat(_ format: CaptureFormat) async throws

    /// Set the target frame rate. Must be supported by the active format.
    func setTargetFPS(_ fps: Double) async throws

    // MARK: Focus

    /// Set focus mode with an optional interest point.
    func setFocus(mode: FocusMode, at point: NormalizedPoint?) async throws

    // MARK: Exposure

    /// Set exposure mode with an optional interest point.
    func setExposure(mode: ExposureMode, at point: NormalizedPoint?) async throws

    /// Set exposure compensation in EV units.
    func setExposureCompensation(_ ev: Float) async throws

    // MARK: Zoom

    /// Set the zoom factor. Must be within the device's supported range.
    func setZoomFactor(_ factor: Double, animated: Bool) async throws

    // MARK: Torch

    /// Configure the torch (flashlight).
    func setTorch(_ configuration: TorchConfiguration) async throws

    // MARK: Stabilization

    /// Set the video stabilization mode. Must be supported by the active format.
    func setStabilization(_ mode: StabilizationMode) async throws

    // MARK: Orientation

    /// Set the video output orientation.
    func setVideoOrientation(_ orientation: VideoOrientation) async throws

    /// Lock or unlock orientation so output stays stable when the phone rotates.
    func setOrientationLocked(_ locked: Bool) async throws
}

// MARK: - Camera Capability Providing

/// Provides dynamic capability information about available cameras and formats.
///
/// All capabilities are discovered at runtime — never hard-coded.
public protocol CameraCapabilityProviding: Sendable {

    /// Discover all available camera devices on this hardware.
    func availableDevices() async -> [CameraDevice]

    /// List supported capture formats for a specific device.
    func supportedFormats(for device: CameraDevice) async -> [CaptureFormat]

    /// List stabilization modes supported by a specific format.
    func supportedStabilizationModes(for format: CaptureFormat) async -> [StabilizationMode]

    /// Whether the device supports torch in the current configuration.
    func isTorchAvailable() async -> Bool

    /// Minimum zoom factor for the current device.
    func minZoomFactor() async -> Double

    /// Maximum zoom factor for the current device and format.
    func maxZoomFactor() async -> Double

    /// Range of supported exposure compensation values in EV.
    func exposureCompensationRange() async -> ClosedRange<Float>

    /// The current camera state snapshot.
    func currentState() async -> CameraState

    /// Aggregated capability summary for the current hardware.
    func capabilities() async -> CameraCapability
}
