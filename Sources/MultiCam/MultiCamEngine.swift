// MultiCamEngine.swift
// MultiCam — Actor-isolated multi-camera capture session owner and pipeline controller.
// Conforms to MultiCamControlling and MultiCamCapabilityProviding.

import AVFoundation
import CoreMedia
import CoreVideo
import Domain
import Camera
import os

// MARK: - MultiCam Engine

/// Production-grade actor managing simultaneous capture across 1, 2, or 3 physical camera devices.
public actor MultiCamEngine: MultiCamControlling, MultiCamCapabilityProviding {

    // MARK: - Core AVFoundation Session

    /// The underlying multi-camera capture session.
    private let session: AVCaptureSession

    /// Whether the session instance is an AVCaptureMultiCamSession.
    private let isMultiCamSession: Bool

    // MARK: - Per-Slot Capture Infrastructure

    /// Attached AVCaptureDeviceInput per slot.
    private var inputs: [MultiCamSlot: AVCaptureDeviceInput] = [:]

    /// Attached AVCaptureVideoDataOutput per slot.
    private var outputs: [MultiCamSlot: AVCaptureVideoDataOutput] = [:]

    /// Underlying AVCaptureDevice per slot.
    private var avDevices: [MultiCamSlot: AVCaptureDevice] = [:]

    /// Dedicated per-slot delegates.
    private var delegates: [MultiCamSlot: MultiCamCaptureDelegate] = [:]

    /// Dedicated serial dispatch queues per slot to prevent cross-camera blocking.
    private let slotQueues: [MultiCamSlot: DispatchQueue] = [
        .primary: DispatchQueue(label: "com.tamandicam.multicam.slot.primary", qos: .userInteractive),
        .secondary: DispatchQueue(label: "com.tamandicam.multicam.slot.secondary", qos: .userInteractive),
        .tertiary: DispatchQueue(label: "com.tamandicam.multicam.slot.tertiary", qos: .userInteractive)
    ]

    // MARK: - Pipeline Subsystems

    /// Multi-channel timestamp alignment synchronizer.
    private let synchronizer = FrameSynchronizer()

    /// Metal/CoreImage composite frame renderer.
    private let compositor = MultiCamCompositor()

    /// Dynamic capability detector and cost analyzer.
    private let capabilityDetector = MultiCamCapabilityDetector()

    /// Fallback and graceful degradation handler.
    private let fallbackHandler = MultiCamFallbackHandler()

    /// Performance and telemetry collector.
    public let diagnosticsCollector = MultiCamDiagnosticsCollector()

    /// Logger for structured engine logs.
    private let logger = Logger(subsystem: "com.tamandicam", category: "MultiCamEngine")

    // MARK: - State

    private var _state = MultiCamState()
    private var targetResolution = Resolution(width: 1920, height: 1080)
    private var interruptionObserver: NSObjectProtocol?
    private var interruptionEndedObserver: NSObjectProtocol?

    // MARK: - Stream Deliveries

    nonisolated(unsafe) private var independentContinuation: AsyncStream<MultiCamSampleFrame>.Continuation?
    nonisolated(unsafe) private var compositeContinuation: AsyncStream<VideoFrame>.Continuation?

    /// Stream of independent camera frames tagged by slot.
    public nonisolated let independentFrames: AsyncStream<MultiCamSampleFrame>

    /// Stream of unified composite video frames (for dual/triple composite modes).
    public nonisolated let compositeFrames: AsyncStream<VideoFrame>

    // MARK: - Initialization

    public init() {
        if AVCaptureMultiCamSession.isMultiCamSupported {
            self.session = AVCaptureMultiCamSession()
            self.isMultiCamSession = true
        } else {
            self.session = AVCaptureSession()
            self.isMultiCamSession = false
        }

        let (indStream, indCont) = AsyncStream.makeStream(of: MultiCamSampleFrame.self, bufferingPolicy: .bufferingNewest(5))
        self.independentFrames = indStream
        self.independentContinuation = indCont

        let (compStream, compCont) = AsyncStream.makeStream(of: VideoFrame.self, bufferingPolicy: .bufferingNewest(3))
        self.compositeFrames = compStream
        self.compositeContinuation = compCont
    }

    deinit {
        independentContinuation?.finish()
        compositeContinuation?.finish()
    }

    // MARK: - MultiCamControlling Lifecycle

    public func startSession() async throws {
        logger.info("Starting MultiCam capture session")

        // 1. Verify permissions
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { throw MultiCamError.slotConfigurationFailed(slot: .primary, reason: "Camera permission denied") }
        default:
            throw MultiCamError.slotConfigurationFailed(slot: .primary, reason: "Camera permission denied")
        }

        // 2. If no slots are configured, discover and configure default primary camera
        if _state.activeSlots.isEmpty {
            if let defaultDevice = selectDefaultCameraDevice() {
                try await configureSlot(.primary, device: defaultDevice, format: nil)
            } else {
                throw MultiCamError.slotConfigurationFailed(slot: .primary, reason: "No available camera device found")
            }
        }

        registerNotificationObservers()

        session.startRunning()

        updateState {
            $0 = MultiCamState(
                mode: $0.mode,
                activeSlots: $0.activeSlots,
                activeFormats: $0.activeFormats,
                layout: $0.layout,
                targetFPS: $0.targetFPS,
                sessionState: .running,
                hardwareCost: $0.hardwareCost
            )
        }

        logger.info("MultiCam session started in mode: \(self._state.mode.rawValue)")
    }

    public func stopSession() async {
        logger.info("Stopping MultiCam capture session")
        session.stopRunning()
        removeNotificationObservers()
        await synchronizer.flush()
        await diagnosticsCollector.reset()

        updateState {
            $0 = MultiCamState(
                mode: $0.mode,
                activeSlots: $0.activeSlots,
                activeFormats: $0.activeFormats,
                layout: $0.layout,
                targetFPS: $0.targetFPS,
                sessionState: .idle,
                hardwareCost: $0.hardwareCost
            )
        }
        logger.info("MultiCam session stopped")
    }

    // MARK: - Mode & Layout Control

    public func setMode(_ mode: CameraMode) async throws {
        logger.info("Transitioning MultiCam mode to: \(mode.rawValue)")

        if mode.requiresMultiCam && !isMultiCamSession {
            let decision = fallbackHandler.negotiateFallback(
                requestedMode: mode,
                currentSlots: _state.activeSlots,
                availableCombinations: [],
                reason: .multiCamNotSupported
            )
            logger.warning("Mode \(mode.rawValue) unsupported: \(decision.explanation)")
            throw MultiCamError.unsupportedMode(mode: mode, reason: decision.explanation)
        }

        updateState {
            $0 = MultiCamState(
                mode: mode,
                activeSlots: $0.activeSlots,
                activeFormats: $0.activeFormats,
                layout: $0.layout ?? defaultLayout(for: mode),
                targetFPS: $0.targetFPS,
                sessionState: $0.sessionState,
                hardwareCost: $0.hardwareCost
            )
        }

        await synchronizer.setActiveSlots(Set(_state.activeSlots.keys))
    }

    public func setCompositeLayout(_ layout: CompositeLayout) async throws {
        updateState {
            $0 = MultiCamState(
                mode: $0.mode,
                activeSlots: $0.activeSlots,
                activeFormats: $0.activeFormats,
                layout: layout,
                targetFPS: $0.targetFPS,
                sessionState: $0.sessionState,
                hardwareCost: $0.hardwareCost
            )
        }
        logger.info("Composite layout updated")
    }

    public func setTargetFPS(_ fps: Double) async throws {
        for (slot, device) in avDevices {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.unlockForConfiguration()
            logger.info("Set target FPS to \(fps) on slot \(slot.rawValue)")
        }

        updateState {
            $0 = MultiCamState(
                mode: $0.mode,
                activeSlots: $0.activeSlots,
                activeFormats: $0.activeFormats,
                layout: $0.layout,
                targetFPS: fps,
                sessionState: $0.sessionState,
                hardwareCost: $0.hardwareCost
            )
        }
    }

    // MARK: - Slot Configuration

    public func configureSlot(_ slot: MultiCamSlot, device: CameraDevice, format: CaptureFormat?) async throws {
        logger.info("Configuring \(slot.description) with device: \(device.name) (\(device.id))")

        guard let avDevice = AVCaptureDevice(uniqueID: device.id) else {
            throw MultiCamError.slotConfigurationFailed(slot: slot, reason: "Device not found on system: \(device.id)")
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Remove existing input/output for this slot if any
        teardownSlot(slot)

        // Create Input
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: avDevice)
        } catch {
            throw MultiCamError.slotConfigurationFailed(slot: slot, reason: error.localizedDescription)
        }

        guard session.canAddInput(input) else {
            throw MultiCamError.slotConfigurationFailed(slot: slot, reason: "Cannot add input to MultiCam session")
        }
        session.addInputWithNoConnections(input)
        inputs[slot] = input
        avDevices[slot] = avDevice

        // Apply format if specified or select best multi-cam format
        if let targetFmt = format {
            if let matchingAVFormat = findAVFormat(matching: targetFmt, in: avDevice) {
                try avDevice.lockForConfiguration()
                avDevice.activeFormat = matchingAVFormat
                avDevice.unlockForConfiguration()
            }
        } else if isMultiCamSession {
            if let bestMultiCam = avDevice.formats.first(where: { $0.isMultiCamSupported }) {
                try avDevice.lockForConfiguration()
                avDevice.activeFormat = bestMultiCam
                avDevice.unlockForConfiguration()
            }
        }

        // Create Output
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        let delegate = MultiCamCaptureDelegate(slot: slot, cameraID: device.id)
        let queue = slotQueues[slot] ?? DispatchQueue(label: "com.tamandicam.multicam.slot.\(slot.rawValue)")
        output.setSampleBufferDelegate(delegate, queue: queue)

        guard session.canAddOutput(output) else {
            throw MultiCamError.slotConfigurationFailed(slot: slot, reason: "Cannot add output to MultiCam session")
        }
        session.addOutputWithNoConnections(output)
        outputs[slot] = output
        delegates[slot] = delegate

        // Connect Input Port to Output
        guard let port = input.ports.first(where: { $0.mediaType == .video }) else {
            throw MultiCamError.slotConfigurationFailed(slot: slot, reason: "No video port on device input")
        }

        let connection = AVCaptureConnection(inputPorts: [port], output: output)
        guard session.canAddConnection(connection) else {
            throw MultiCamError.slotConfigurationFailed(slot: slot, reason: "Cannot connect input port to output")
        }
        session.addConnection(connection)

        // Wire delegate callback into frame processing pipeline
        wireDelegate(delegate, for: slot)

        // Update state
        var activeSlots = _state.activeSlots
        activeSlots[slot] = device

        var activeFormats = _state.activeFormats
        let activeIdx = avDevice.formats.firstIndex(of: avDevice.activeFormat) ?? 0
        activeFormats[slot] = mapFormat(avDevice.activeFormat, index: activeIdx)

        let estimatedCost = capabilityDetector.calculateCost(
            deviceCount: activeSlots.count,
            primaryResolution: activeFormats[.primary]?.resolution ?? Resolution(width: 1920, height: 1080),
            fps: _state.targetFPS
        )

        updateState {
            $0 = MultiCamState(
                mode: $0.mode,
                activeSlots: activeSlots,
                activeFormats: activeFormats,
                layout: $0.layout ?? self.defaultLayout(for: $0.mode),
                targetFPS: $0.targetFPS,
                sessionState: $0.sessionState,
                hardwareCost: estimatedCost
            )
        }

        await synchronizer.setActiveSlots(Set(activeSlots.keys))
        logger.info("Successfully configured \(slot.description)")
    }

    public func removeSlot(_ slot: MultiCamSlot) async throws {
        guard _state.activeSlots[slot] != nil else { return }
        logger.info("Removing \(slot.description)")

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        teardownSlot(slot)

        var activeSlots = _state.activeSlots
        activeSlots.removeValue(forKey: slot)

        var activeFormats = _state.activeFormats
        activeFormats.removeValue(forKey: slot)

        updateState {
            $0 = MultiCamState(
                mode: $0.mode,
                activeSlots: activeSlots,
                activeFormats: activeFormats,
                layout: $0.layout,
                targetFPS: $0.targetFPS,
                sessionState: $0.sessionState,
                hardwareCost: $0.hardwareCost
            )
        }

        await synchronizer.setActiveSlots(Set(activeSlots.keys))
    }

    // MARK: - MultiCamCapabilityProviding

    public func isMultiCamSupported() async -> Bool {
        MultiCamCapabilityDetector.isMultiCamSupported
    }

    public func availableMultiCamCombinations() async -> [MultiCamDeviceCombination] {
        capabilityDetector.discoverSupportedCombinations()
    }

    public func supportedCombinations(for mode: CameraMode) async -> [MultiCamDeviceCombination] {
        let all = capabilityDetector.discoverSupportedCombinations()
        return all.filter { $0.devices.count >= mode.cameraCount }
    }

    public func currentState() async -> MultiCamState {
        _state
    }

    public func currentHardwareCost() async -> Float {
        _state.hardwareCost
    }

    // MARK: - Private Processing Pipeline

    private func wireDelegate(_ delegate: MultiCamCaptureDelegate, for slot: MultiCamSlot) {
        delegate.onFrame = { [weak self] sampleFrame in
            guard let self else { return }
            Task { await self.handleSampleFrame(sampleFrame) }
        }

        delegate.onDrop = { [weak self] droppedSlot in
            guard let self else { return }
            Task { await self.diagnosticsCollector.recordDrop(for: droppedSlot) }
        }
    }

    private func handleSampleFrame(_ frame: MultiCamSampleFrame) async {
        // Yield to independent frames stream
        independentContinuation?.yield(frame)
        await diagnosticsCollector.recordFrame(for: frame.slot)

        // If in composite mode, synchronize and render composite frame
        if _state.mode == .dualComposite || _state.mode == .tripleComposite {
            if let frameSet = await synchronizer.enqueue(frame),
               let layout = _state.layout {
                do {
                    let pixelBuffer = try compositor.composite(
                        frameSet: frameSet,
                        layout: layout,
                        targetResolution: targetResolution
                    )
                    let sampleBuffer = try compositor.makeSampleBuffer(
                        from: pixelBuffer,
                        timestamp: frameSet.referenceTimestamp
                    )
                    let compFrame = VideoFrame(
                        sampleBuffer: sampleBuffer,
                        timestamp: frameSet.referenceTimestamp,
                        cameraID: "multicam_composite"
                    )
                    compositeContinuation?.yield(compFrame)
                    await diagnosticsCollector.recordCompositeFrame(driftMs: frameSet.maxDriftMs)
                } catch {
                    logger.error("Composition error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func teardownSlot(_ slot: MultiCamSlot) {
        if let input = inputs.removeValue(forKey: slot) {
            session.removeInput(input)
        }
        if let output = outputs.removeValue(forKey: slot) {
            session.removeOutput(output)
        }
        delegates.removeValue(forKey: slot)
        avDevices.removeValue(forKey: slot)
    }

    private func selectDefaultCameraDevice() -> CameraDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: .back
        )
        guard let avDev = discovery.devices.first else { return nil }
        return CameraDevice(
            id: avDev.uniqueID,
            name: avDev.localizedName,
            position: .back,
            lensType: .wide,
            hasTorch: avDev.hasTorch,
            isFocusLockSupported: true,
            isExposureLockSupported: true,
            maxZoomFactor: Double(avDev.activeFormat.videoMaxZoomFactor),
            videoFieldOfView: avDev.activeFormat.videoFieldOfView
        )
    }

    private func defaultLayout(for mode: CameraMode) -> CompositeLayout? {
        switch mode {
        case .single, .dualIndependent, .tripleIndependent:
            return nil
        case .dualComposite:
            return .pictureInPicture(position: .topRight, sizeFraction: 0.30)
        case .tripleComposite:
            return .threeGrid(primaryOnTop: true)
        }
    }

    private func updateState(_ mutation: (inout MultiCamState) -> Void) {
        var state = _state
        mutation(&state)
        _state = state
    }

    // MARK: - Notifications

    private func registerNotificationObservers() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: session,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.handleInterruption() }
        }

        interruptionEndedObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: session,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.handleInterruptionEnded() }
        }
    }

    private func removeNotificationObservers() {
        if let obs = interruptionObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = interruptionEndedObserver { NotificationCenter.default.removeObserver(obs) }
        interruptionObserver = nil
        interruptionEndedObserver = nil
    }

    private func handleInterruption() {
        logger.warning("MultiCam session interrupted")
        updateState {
            $0 = MultiCamState(
                mode: $0.mode,
                activeSlots: $0.activeSlots,
                activeFormats: $0.activeFormats,
                layout: $0.layout,
                targetFPS: $0.targetFPS,
                sessionState: .error,
                hardwareCost: $0.hardwareCost
            )
        }
    }

    private func handleInterruptionEnded() {
        logger.info("MultiCam session interruption ended")
        if !session.isRunning {
            session.startRunning()
        }
        updateState {
            $0 = MultiCamState(
                mode: $0.mode,
                activeSlots: $0.activeSlots,
                activeFormats: $0.activeFormats,
                layout: $0.layout,
                targetFPS: $0.targetFPS,
                sessionState: .running,
                hardwareCost: $0.hardwareCost
            )
        }
    }

    private func findAVFormat(matching domainFormat: CaptureFormat, in device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        device.formats.first { avFormat in
            let dims = CMVideoFormatDescriptionGetDimensions(avFormat.formatDescription)
            return Int(dims.width) == domainFormat.resolution.width &&
                   Int(dims.height) == domainFormat.resolution.height
        }
    }

    private func mapFormat(_ avFormat: AVCaptureDevice.Format, index: Int) -> CaptureFormat {
        let dims = CMVideoFormatDescriptionGetDimensions(avFormat.formatDescription)
        let res = Resolution(width: Int(dims.width), height: Int(dims.height))
        let ranges = avFormat.videoSupportedFrameRateRanges.map {
            FPSRange(minFrameRate: $0.minFrameRate, maxFrameRate: $0.maxFrameRate)
        }
        return CaptureFormat(
            id: "format_\(index)_\(res.description)",
            resolution: res,
            fpsRanges: ranges,
            pixelFormats: [.yuv420BiPlanarVideoRange],
            supportedStabilizationModes: [.off, .standard],
            maxZoomFactor: Double(avFormat.videoMaxZoomFactor),
            videoZoomFactorUpscaleThreshold: Double(avFormat.videoZoomFactorUpscaleThreshold),
            isVideoBinned: avFormat.isVideoBinned,
            isMultiCamSupported: avFormat.isMultiCamSupported,
            videoFieldOfView: avFormat.videoFieldOfView,
            highResolutionStillImageDimensions: nil
        )
    }
}
