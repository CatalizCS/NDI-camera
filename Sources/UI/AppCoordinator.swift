// AppCoordinator.swift
// UI — Wires all engine modules together and manages app lifecycle.

import SwiftUI
import Domain
import Camera
import Audio
import NDI
import Diagnostics
import Persistence

#if canImport(Remote)
import Remote
#endif

/// Central coordinator that owns all subsystem engines and manages app state.
/// Injected as an `@Observable` environment object for UI consumption.
@Observable
@MainActor
public final class AppCoordinator {

    // MARK: - Published State

    public var cameraState: CameraState = CameraState()
    public var audioState: AudioState = AudioState()
    public var isStreaming: Bool = false
    public var streamState: StreamState = .idle
    public var pairingCode: String? = nil
    public var remoteServerRunning: Bool = false
    public var thermalState: ThermalState = .nominal
    public var displayMode: DisplayMode = .normal

    // MARK: - Engines

    public private(set) var cameraEngine: CameraEngine?
    public private(set) var audioEngine: AudioEngine?
    public private(set) var ndiSender: NDISender?
    public private(set) var diagnosticsEngine: DiagnosticsEngine?
    public private(set) var settingsStore: SettingsStore?
    public private(set) var presetManager: PresetManager?

    #if canImport(Remote) && canImport(Network)
    public private(set) var remoteServer: RemoteServer?
    #endif

    // MARK: - Init

    public init() {}

    // MARK: - Lifecycle

    /// Start all subsystems in the correct order.
    public func start() async {
        // 1. Persistence (settings must load first)
        let store = SettingsStore()
        self.settingsStore = store
        self.presetManager = PresetManager(settingsStore: store)

        // 2. Diagnostics
        let diag = DiagnosticsEngine()
        self.diagnosticsEngine = diag

        // 3. Camera (dynamically discover devices)
        let camera = CameraEngine()
        self.cameraEngine = camera

        // 4. Audio
        let audio = AudioEngine()
        self.audioEngine = audio

        // 5. NDI (mock backend — real backend requires SDK)
        let mockBackend = MockNDIBackend()
        let sender = NDISender(backend: mockBackend)
        self.ndiSender = sender

        // 6. Apply persisted settings
        if let store = settingsStore {
            let saved = await store.currentSettings()
            await applyPersistedSettings(saved)
        }

        // Keep screen awake by default
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// Stop all subsystems gracefully.
    public func stop() async {
        #if canImport(Remote) && canImport(Network)
        await remoteServer?.stopServer()
        #endif
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Stream Control

    public func startStream() async {
        guard streamState == .idle else { return }
        streamState = .starting
        isStreaming = true

        do {
            try await cameraEngine?.startSession()
            try await audioEngine?.start()
            streamState = .streaming
        } catch {
            streamState = .error
            isStreaming = false
        }
    }

    public func stopStream() async {
        guard streamState == .streaming else { return }
        streamState = .stopping

        await cameraEngine?.stopSession()
        await audioEngine?.stop()

        streamState = .idle
        isStreaming = false
    }

    public func toggleStream() async {
        if isStreaming {
            await stopStream()
        } else {
            await startStream()
        }
    }

    // MARK: - Camera Controls

    public func selectCamera(_ device: CameraDevice) async {
        try? await cameraEngine?.selectDevice(device)
    }

    public func setZoom(_ factor: Double) async {
        try? await cameraEngine?.setZoomFactor(factor)
    }

    public func setTorch(enabled: Bool, level: Float = 1.0) async {
        try? await cameraEngine?.setTorch(enabled: enabled, level: level)
    }

    // MARK: - Remote Server

    public func startRemoteServer(port: UInt16 = 5353) async {
        #if canImport(Remote) && canImport(Network)
        remoteServerRunning = true
        #endif
    }

    public func stopRemoteServer() async {
        #if canImport(Remote) && canImport(Network)
        await remoteServer?.stopServer()
        remoteServerRunning = false
        #endif
    }

    // MARK: - Display Mode

    public func setDisplayMode(_ mode: DisplayMode) {
        displayMode = mode
    }

    // MARK: - Private

    private func applyPersistedSettings(_ settings: PresetSettings) async {
        // Apply saved settings to engines when they support it
    }
}
