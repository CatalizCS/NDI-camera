// AudioEngine.swift
// Audio — Actor-based audio engine orchestrating hardware routing, capture, and DSP.
// Conforms to AudioControlling and AudioCapabilityProviding from Domain.

import Foundation
import AVFoundation
import CoreMedia
import Domain
import os

// MARK: - Audio Engine

/// Production-grade audio engine for TamaNDI.
///
/// All hardware mutations and state queries are serialized through actor isolation.
/// Audio frame delivery occurs on real-time queues via `AsyncStream<AudioFrame>` without blocking the main thread.
public actor AudioEngine: AudioControlling, AudioCapabilityProviding {

    // MARK: - Subsystem Components

    private let sessionManager: AudioSessionManager
    private let capturePipeline: AudioCapturePipeline
    private let routeDiscoverer: AudioRouteDiscoverer
    private let logger = Logger(subsystem: "com.tamandicam", category: "AudioEngine")

    // MARK: - State

    private var _state = AudioState()
    private var configuration = AudioConfiguration()

    // MARK: - Frame Delivery

    nonisolated(unsafe) private var frameContinuation: AsyncStream<AudioFrame>.Continuation?

    /// Continuous stream of captured, synchronized audio frames for downstream consumers (e.g., NDI).
    public nonisolated let audioFrames: AsyncStream<AudioFrame>

    // MARK: - Initialization

    public init(
        sessionManager: AudioSessionManager = AudioSessionManager(),
        capturePipeline: AudioCapturePipeline = AudioCapturePipeline(),
        routeDiscoverer: AudioRouteDiscoverer = AudioRouteDiscoverer()
    ) {
        self.sessionManager = sessionManager
        self.capturePipeline = capturePipeline
        self.routeDiscoverer = routeDiscoverer

        let (stream, continuation) = AsyncStream.makeStream(
            of: AudioFrame.self,
            bufferingPolicy: .bufferingNewest(5)
        )
        self.audioFrames = stream
        self.frameContinuation = continuation

        // Setup notification event handlers
        setupEventHandlers()
    }

    deinit {
        frameContinuation?.finish()
    }

    // MARK: - AudioControlling: Session Lifecycle

    public func start() async throws {
        logger.info("Starting audio engine")

        guard !_state.isRunning else {
            logger.warning("Audio engine is already running")
            return
        }

        // 1. Check microphone authorization
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch authStatus {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else { throw AudioError.permissionDenied }
        case .denied, .restricted:
            throw AudioError.permissionDenied
        @unknown default:
            throw AudioError.permissionDenied
        }

        // 2. Configure and activate audio session
        try sessionManager.configureAndActivate(configuration: configuration)

        // 3. Discover active route and inputs
        let activeDevice = routeDiscoverer.currentInputDevice()

        // 4. Start capture pipeline with continuation
        guard let continuation = frameContinuation else {
            throw AudioError.engineStartFailed(reason: "Frame continuation is nil")
        }

        try capturePipeline.start(continuation: continuation)

        // 5. Update state
        updateState {
            $0 = AudioState(
                isRunning: true,
                isMuted: self.capturePipeline.isMuted,
                gain: self.capturePipeline.gain,
                isHardwareGainSupported: self.sessionManager.isInputGainSettable,
                selectedDevice: activeDevice,
                selectedDataSource: activeDevice?.selectedDataSource,
                sampleRate: self.configuration.sampleRate,
                channelLayout: self.configuration.channelLayout,
                sessionState: .running
            )
        }

        logger.info("Audio engine started successfully (Device: \(activeDevice?.name ?? "Default"))")
    }

    public func stop() async {
        logger.info("Stopping audio engine")
        capturePipeline.stop()
        sessionManager.deactivate()

        updateState {
            $0 = AudioState(
                isRunning: false,
                isMuted: self.capturePipeline.isMuted,
                gain: self.capturePipeline.gain,
                isHardwareGainSupported: self.sessionManager.isInputGainSettable,
                selectedDevice: $0.selectedDevice,
                selectedDataSource: $0.selectedDataSource,
                sampleRate: $0.sampleRate,
                channelLayout: $0.channelLayout,
                sessionState: .idle
            )
        }
        logger.info("Audio engine stopped")
    }

    // MARK: - Device & Route Selection

    public func selectDevice(_ device: AudioInputDevice) async throws {
        logger.info("Selecting audio device: \(device.name) (\(device.id))")
        try sessionManager.selectPort(byID: device.id)

        if let ds = device.selectedDataSource {
            try sessionManager.selectDataSource(id: ds.id, polarPattern: ds.polarPattern)
        }

        let updatedDevice = routeDiscoverer.currentInputDevice()
        updateState {
            $0 = AudioState(
                isRunning: $0.isRunning,
                isMuted: $0.isMuted,
                gain: $0.gain,
                isHardwareGainSupported: self.sessionManager.isInputGainSettable,
                selectedDevice: updatedDevice ?? device,
                selectedDataSource: updatedDevice?.selectedDataSource ?? device.selectedDataSource,
                sampleRate: $0.sampleRate,
                channelLayout: $0.channelLayout,
                sessionState: $0.sessionState
            )
        }
        logger.info("Audio device selected: \(device.name)")
    }

    public func selectDataSource(_ dataSource: AudioDataSource?) async throws {
        logger.info("Selecting audio data source: \(dataSource?.name ?? "Default")")
        try sessionManager.selectDataSource(id: dataSource?.id, polarPattern: dataSource?.polarPattern)

        let updatedDevice = routeDiscoverer.currentInputDevice()
        updateState {
            $0 = AudioState(
                isRunning: $0.isRunning,
                isMuted: $0.isMuted,
                gain: $0.gain,
                isHardwareGainSupported: self.sessionManager.isInputGainSettable,
                selectedDevice: updatedDevice,
                selectedDataSource: dataSource,
                sampleRate: $0.sampleRate,
                channelLayout: $0.channelLayout,
                sessionState: $0.sessionState
            )
        }
    }

    // MARK: - Format & Settings

    public func setSampleRate(_ sampleRate: AudioSampleRate) async throws {
        logger.info("Setting audio sample rate: \(sampleRate.displayName)")
        configuration.sampleRate = sampleRate
        if _state.isRunning {
            try sessionManager.configureAndActivate(configuration: configuration)
        }
        updateState {
            $0 = AudioState(
                isRunning: $0.isRunning,
                isMuted: $0.isMuted,
                gain: $0.gain,
                isHardwareGainSupported: $0.isHardwareGainSupported,
                selectedDevice: $0.selectedDevice,
                selectedDataSource: $0.selectedDataSource,
                sampleRate: sampleRate,
                channelLayout: $0.channelLayout,
                sessionState: $0.sessionState
            )
        }
    }

    public func setChannelLayout(_ layout: AudioChannelLayout) async throws {
        logger.info("Setting audio channel layout: \(layout.displayName)")
        configuration.channelLayout = layout
        updateState {
            $0 = AudioState(
                isRunning: $0.isRunning,
                isMuted: $0.isMuted,
                gain: $0.gain,
                isHardwareGainSupported: $0.isHardwareGainSupported,
                selectedDevice: $0.selectedDevice,
                selectedDataSource: $0.selectedDataSource,
                sampleRate: $0.sampleRate,
                channelLayout: layout,
                sessionState: $0.sessionState
            )
        }
    }

    public func setGain(_ gain: Float) async throws {
        let clampedGain = max(0.0, gain)
        logger.info("Setting audio gain: \(clampedGain)")

        if sessionManager.isInputGainSettable {
            try? sessionManager.setHardwareGain(clampedGain)
        }

        // Apply software gain multiplier in pipeline
        capturePipeline.gain = clampedGain

        updateState {
            $0 = AudioState(
                isRunning: $0.isRunning,
                isMuted: $0.isMuted,
                gain: clampedGain,
                isHardwareGainSupported: self.sessionManager.isInputGainSettable,
                selectedDevice: $0.selectedDevice,
                selectedDataSource: $0.selectedDataSource,
                sampleRate: $0.sampleRate,
                channelLayout: $0.channelLayout,
                sessionState: $0.sessionState
            )
        }
    }

    public func setMuted(_ isMuted: Bool) async {
        logger.info("Setting audio mute: \(isMuted)")
        capturePipeline.isMuted = isMuted

        updateState {
            $0 = AudioState(
                isRunning: $0.isRunning,
                isMuted: isMuted,
                gain: $0.gain,
                isHardwareGainSupported: $0.isHardwareGainSupported,
                selectedDevice: $0.selectedDevice,
                selectedDataSource: $0.selectedDataSource,
                sampleRate: $0.sampleRate,
                channelLayout: $0.channelLayout,
                sessionState: $0.sessionState
            )
        }
    }

    // MARK: - AudioCapabilityProviding

    public func availableInputDevices() async -> [AudioInputDevice] {
        routeDiscoverer.discoverAvailableInputs()
    }

    public func currentDevice() async -> AudioInputDevice? {
        routeDiscoverer.currentInputDevice()
    }

    public func supportedSampleRates(for device: AudioInputDevice) async -> [AudioSampleRate] {
        // Standard broadcast and hi-res rates
        [.rate48000, .rate44100, .rate96000]
    }

    public func supportedChannelCounts(for device: AudioInputDevice) async -> [Int] {
        if device.channels > 1 {
            return [1, 2]
        }
        return [1]
    }

    public func isHardwareGainSettable() async -> Bool {
        sessionManager.isInputGainSettable
    }

    public func currentState() async -> AudioState {
        _state
    }

    public func currentLevels() async -> AudioLevelsSnapshot {
        capturePipeline.latestLevels
    }

    // MARK: - Internal Event Observers

    private func setupEventHandlers() {
        sessionManager.eventHandlers = AudioSessionEventHandlers(
            onInterruptionBegan: { [weak self] in
                guard let self else { return }
                Task { await self.handleInterruptionBegan() }
            },
            onInterruptionEnded: { [weak self] shouldResume in
                guard let self else { return }
                Task { await self.handleInterruptionEnded(shouldResume: shouldResume) }
            },
            onRouteChange: { [weak self] reason in
                guard let self else { return }
                Task { await self.handleRouteChange(reason: reason) }
            },
            onMediaServicesReset: { [weak self] in
                guard let self else { return }
                Task { await self.handleMediaServicesReset() }
            }
        )
    }

    private func handleInterruptionBegan() {
        logger.warning("Audio interruption began — pausing capture")
        capturePipeline.stop()
        updateState {
            $0 = AudioState(
                isRunning: false,
                isMuted: $0.isMuted,
                gain: $0.gain,
                isHardwareGainSupported: $0.isHardwareGainSupported,
                selectedDevice: $0.selectedDevice,
                selectedDataSource: $0.selectedDataSource,
                sampleRate: $0.sampleRate,
                channelLayout: $0.channelLayout,
                sessionState: .idle
            )
        }
    }

    private func handleInterruptionEnded(shouldResume: Bool) {
        logger.info("Audio interruption ended (shouldResume: \(shouldResume))")
        guard shouldResume, let continuation = frameContinuation else { return }

        do {
            try capturePipeline.start(continuation: continuation)
            updateState {
                $0 = AudioState(
                    isRunning: true,
                    isMuted: $0.isMuted,
                    gain: $0.gain,
                    isHardwareGainSupported: $0.isHardwareGainSupported,
                    selectedDevice: $0.selectedDevice,
                    selectedDataSource: $0.selectedDataSource,
                    sampleRate: $0.sampleRate,
                    channelLayout: $0.channelLayout,
                    sessionState: .running
                )
            }
        } catch {
            logger.error("Failed to resume audio capture after interruption: \(error.localizedDescription)")
        }
    }

    private func handleRouteChange(reason: AVAudioSession.RouteChangeReason) {
        logger.info("Handling route change reason: \(String(describing: reason))")
        let activeDevice = routeDiscoverer.currentInputDevice()
        updateState {
            $0 = AudioState(
                isRunning: $0.isRunning,
                isMuted: $0.isMuted,
                gain: $0.gain,
                isHardwareGainSupported: self.sessionManager.isInputGainSettable,
                selectedDevice: activeDevice ?? $0.selectedDevice,
                selectedDataSource: activeDevice?.selectedDataSource ?? $0.selectedDataSource,
                sampleRate: $0.sampleRate,
                channelLayout: $0.channelLayout,
                sessionState: $0.sessionState
            )
        }
    }

    private func handleMediaServicesReset() {
        logger.warning("Handling media services reset — reconfiguring audio engine")
        capturePipeline.stop()
        if _state.isRunning {
            Task {
                try? await self.start()
            }
        }
    }

    private func updateState(_ mutation: (inout AudioState) -> Void) {
        var state = _state
        mutation(&state)
        _state = state
    }
}
