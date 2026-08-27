// CameraEngine.swift
// Camera — Actor-based camera engine.
//
// Owns the AVCaptureSession and serializes all mutations through actor isolation.
// Conforms to CameraControlling and CameraCapabilityProviding from Domain.
// All capabilities are discovered dynamically — never hard-coded.

import AVFoundation
import CoreMedia
import Domain
import os

// MARK: - Camera Engine

/// Production-grade camera engine built on AVFoundation.
///
/// All session mutations are serialized through actor isolation.
/// Frame delivery uses a dedicated serial queue — never the main thread.
/// Capabilities are discovered dynamically from the actual hardware.
public actor CameraEngine: CameraControlling, CameraCapabilityProviding {

    // MARK: - Private State

    /// The capture session. Owned exclusively by this actor.
    private let session = AVCaptureSession()

    /// Serial queue for video data output callbacks. Never the main thread.
    private let videoOutputQueue = DispatchQueue(
        label: "com.tamandicam.videoOutput",
        qos: .userInteractive
    )

    /// Serial queue for audio data output callbacks.
    private let audioOutputQueue = DispatchQueue(
        label: "com.tamandicam.audioOutput",
        qos: .userInteractive
    )

    /// Video data output.
    private var videoOutput: AVCaptureVideoDataOutput?

    /// Current device input attached to the session.
    private var currentInput: AVCaptureDeviceInput?

    /// The underlying AVCaptureDevice for the current input.
    private var currentAVDevice: AVCaptureDevice?

    /// Video capture delegate. Forwarding frames via callback.
    private let videoCaptureDelegate = VideoCaptureDelegate()

    /// Discovered camera devices (cached after discovery).
    private var discoveredDevices: [CameraDevice] = []

    /// Cached format list for the current device.
    private var currentDeviceFormats: [CaptureFormat] = []

    /// Logger for structured diagnostics.
    private let logger = Logger(subsystem: "com.tamandicam", category: "CameraEngine")

    // MARK: - Published State

    /// Current camera state snapshot. Updated after every mutation.
    private var _state = CameraState()

    /// Video orientation (may differ from UI orientation when locked).
    private var _videoOrientation: VideoOrientation = .auto

    /// Whether orientation is locked.
    private var _isOrientationLocked = false

    /// Active stabilization mode.
    private var _stabilizationMode: StabilizationMode = .off

    /// Notification observers.
    private var interruptionObserver: NSObjectProtocol?
    private var interruptionEndedObserver: NSObjectProtocol?

    // MARK: - Frame Delivery

    /// Continuation for the video frame async stream.
    /// `nonisolated(unsafe)` because it must be accessible from deinit (which is nonisolated)
    /// and from the video output delegate callback queue. Thread safety is guaranteed by:
    /// - The continuation is set once in init (before any concurrent access)
    /// - `finish()` is idempotent and safe to call from deinit
    /// - `yield()` is called from the serialized videoOutputQueue
    nonisolated(unsafe) private var videoFrameContinuation: AsyncStream<VideoFrame>.Continuation?

    /// Stream of captured video frames for downstream consumers (e.g., NDI adapter).
    ///
    /// Iterate this stream to receive frames. The stream is terminated when
    /// the session stops or the engine is deinitialized.
    public nonisolated let videoFrames: AsyncStream<VideoFrame>

    // MARK: - Initialization

    public init() {
        let (stream, continuation) = AsyncStream.makeStream(of: VideoFrame.self, bufferingPolicy: .bufferingNewest(3))
        self.videoFrames = stream
        self.videoFrameContinuation = continuation

        // Wire up delegate → continuation
        videoCaptureDelegate.onFrame = { frame in
            continuation.yield(frame)
        }
        let capturedLogger = self.logger
        videoCaptureDelegate.onFrameDropped = {
            capturedLogger.debug("Video frame dropped by AVFoundation (late processing)")
        }
    }

    deinit {
        videoFrameContinuation?.finish()
    }

    // MARK: - Session Lifecycle

    public func startSession() async throws {
        logger.info("Starting capture session")

        // Check camera permission
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { throw CameraError.cameraPermissionDenied }
        case .denied:
            throw CameraError.cameraPermissionDenied
        case .restricted:
            throw CameraError.cameraPermissionRestricted
        @unknown default:
            throw CameraError.cameraPermissionDenied
        }

        // Discover devices
        discoveredDevices = discoverAllDevices()
        logger.info("Discovered \(self.discoveredDevices.count) camera device(s)")

        // Select a default device if none is selected
        if currentAVDevice == nil {
            if let defaultDevice = selectDefaultDevice() {
                try configureSession(with: defaultDevice)
            } else {
                throw CameraError.deviceNotFound(deviceID: "default")
            }
        }

        // Register for interruption notifications
        registerNotificationObservers()

        // Start running (blocking call, but we're on the actor's queue, not main)
        session.startRunning()
        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: $0.focusMode,
            exposureMode: $0.exposureMode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: .running
        )}
        logger.info("Capture session started")
    }

    public func stopSession() async {
        logger.info("Stopping capture session")
        session.stopRunning()
        removeNotificationObservers()
        videoFrameContinuation?.finish()
        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: $0.focusMode,
            exposureMode: $0.exposureMode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: .idle
        )}
        logger.info("Capture session stopped")
    }

    // MARK: - Device Selection

    public func selectCamera(_ device: CameraDevice) async throws {
        logger.info("Selecting camera: \(device.name) (\(device.id))")

        guard let avDevice = findAVDevice(byID: device.id) else {
            throw CameraError.deviceNotFound(deviceID: device.id)
        }

        try configureSession(with: avDevice)
        logger.info("Camera selected: \(device.name)")
    }

    // MARK: - Format and FPS

    public func setFormat(_ format: CaptureFormat) async throws {
        guard let device = currentAVDevice else {
            throw CameraError.notInitialized
        }

        guard let avFormat = findAVFormat(matching: format, in: device) else {
            throw CameraError.formatNotAvailable(
                width: format.resolution.width,
                height: format.resolution.height,
                fps: format.maxFrameRate
            )
        }

        try device.lockForConfiguration()
        device.activeFormat = avFormat
        device.unlockForConfiguration()

        // Update cached formats and state
        currentDeviceFormats = mapFormats(from: device)
        let domainFormat = mapFormat(avFormat, index: device.formats.firstIndex(of: avFormat) ?? 0)
        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: domainFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: $0.focusMode,
            exposureMode: $0.exposureMode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: $0.sessionState
        )}

        logger.info("Format set: \(format.resolution.description)")
    }

    public func setTargetFPS(_ fps: Double) async throws {
        guard let device = currentAVDevice else {
            throw CameraError.notInitialized
        }

        // Verify the active format supports this FPS
        let activeRanges = device.activeFormat.videoSupportedFrameRateRanges
        guard let matchingRange = activeRanges.first(where: {
            fps >= $0.minFrameRate && fps <= $0.maxFrameRate
        }) else {
            let maxAvailable = activeRanges.map(\.maxFrameRate).max() ?? 0
            throw CameraError.fpsNotSupported(requested: fps, maxAvailable: maxAvailable)
        }

        try device.lockForConfiguration()
        device.activeVideoMinFrameDuration = matchingRange.minFrameDuration
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        device.unlockForConfiguration()

        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: fps,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: $0.focusMode,
            exposureMode: $0.exposureMode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: $0.sessionState
        )}

        logger.info("Target FPS set: \(fps)")
    }

    // MARK: - State

    public func currentState() async -> CameraState {
        _state
    }

    // MARK: - Internal Helpers

    /// Configure the session with a given AVCaptureDevice.
    private func configureSession(with device: AVCaptureDevice) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Remove existing input
        if let existingInput = currentInput {
            session.removeInput(existingInput)
        }

        // Remove existing video output
        if let existingOutput = videoOutput {
            session.removeOutput(existingOutput)
        }

        // Create new input
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraError.inputCreationFailed(reason: error.localizedDescription)
        }

        guard session.canAddInput(input) else {
            throw CameraError.sessionConfigurationFailed(reason: "Cannot add device input to session")
        }
        session.addInput(input)
        currentInput = input
        currentAVDevice = device

        // Create video data output
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        output.setSampleBufferDelegate(videoCaptureDelegate, queue: videoOutputQueue)

        guard session.canAddOutput(output) else {
            throw CameraError.sessionConfigurationFailed(reason: "Cannot add video output to session")
        }
        session.addOutput(output)
        videoOutput = output

        // Update camera ID on delegate
        videoCaptureDelegate.cameraID = device.uniqueID

        // Cache formats
        currentDeviceFormats = mapFormats(from: device)

        // Map current active format
        let activeFormatIndex = device.formats.firstIndex(of: device.activeFormat) ?? 0
        let activeDomainFormat = mapFormat(device.activeFormat, index: activeFormatIndex)
        let domainDevice = mapDevice(device)

        // Read current device state
        let currentFocus = mapFocusMode(device.focusMode)
        let currentExposure = mapExposureMode(device.exposureMode)

        updateState { $0 =
            CameraState(
                selectedDevice: domainDevice,
                activeFormat: activeDomainFormat,
                targetFPS: device.activeFormat.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 30,
                currentZoomFactor: device.videoZoomFactor,
                focusMode: currentFocus,
                exposureMode: currentExposure,
                exposureCompensation: device.exposureTargetBias,
                isTorchActive: device.isTorchActive,
                torchLevel: device.torchLevel,
                stabilizationMode: self._stabilizationMode,
                videoOrientation: self._videoOrientation,
                isOrientationLocked: self._isOrientationLocked,
                sessionState: self.session.isRunning ? .running : .idle
            )
        }

        logger.info("Session configured with device: \(device.localizedName)")
    }

    /// Find an AVCaptureDevice by its unique ID.
    private func findAVDevice(byID id: String) -> AVCaptureDevice? {
        AVCaptureDevice(uniqueID: id)
    }

    /// Select a default back wide-angle camera, or any available camera.
    private func selectDefaultDevice() -> AVCaptureDevice? {
        // Prefer back wide-angle camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        }
        // Fall back to any video device
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.first
    }

    /// Update internal state using a mutation closure.
    private func updateState(_ mutation: (inout CameraState) -> Void) {
        var state = _state
        mutation(&state)
        _state = state
    }

    // MARK: - Notification Observers

    private func registerNotificationObservers() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: session,
            queue: nil
        ) { [weak self] notification in
            guard let self else { return }
            Task { await self.handleInterruption(notification) }
        }

        interruptionEndedObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: session,
            queue: nil
        ) { [weak self] notification in
            guard let self else { return }
            Task { await self.handleInterruptionEnded(notification) }
        }
    }

    private func removeNotificationObservers() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        if let observer = interruptionEndedObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionEndedObserver = nil
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVCaptureSessionInterruptionReasonKey] as? Int,
              let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue) else {
            logger.warning("Session interrupted (unknown reason)")
            return
        }

        let reasonString: String
        switch reason {
        case .videoDeviceNotAvailableInBackground:
            reasonString = "App entered background"
        case .audioDeviceInUseByAnotherClient:
            reasonString = "Audio device in use by another app"
        case .videoDeviceInUseByAnotherClient:
            reasonString = "Camera in use by another app"
        case .videoDeviceNotAvailableWithMultipleForegroundApps:
            reasonString = "Camera unavailable in multi-app mode"
        case .videoDeviceNotAvailableDueToSystemPressure:
            reasonString = "Camera unavailable due to system pressure"
        @unknown default:
            reasonString = "Unknown reason (\(reasonValue))"
        }

        logger.warning("Session interrupted: \(reasonString)")
        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: $0.focusMode,
            exposureMode: $0.exposureMode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: .error
        )}
    }

    private func handleInterruptionEnded(_ notification: Notification) {
        logger.info("Session interruption ended, resuming")
        if !session.isRunning {
            session.startRunning()
        }
        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: $0.focusMode,
            exposureMode: $0.exposureMode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: .running
        )}
    }
}
