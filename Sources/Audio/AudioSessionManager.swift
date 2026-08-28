// AudioSessionManager.swift
// Audio — Manages AVAudioSession configuration, category/mode lifecycle, port routing, and OS notifications.

import AVFoundation
import Domain
import os

// MARK: - Audio Session Event Handlers

public struct AudioSessionEventHandlers: Sendable {
    public var onInterruptionBegan: (@Sendable () -> Void)?
    public var onInterruptionEnded: (@Sendable (Bool) -> Void)?
    public var onRouteChange: (@Sendable (AVAudioSession.RouteChangeReason) -> Void)?
    public var onMediaServicesReset: (@Sendable () -> Void)?

    public init(
        onInterruptionBegan: (@Sendable () -> Void)? = nil,
        onInterruptionEnded: (@Sendable (Bool) -> Void)? = nil,
        onRouteChange: (@Sendable (AVAudioSession.RouteChangeReason) -> Void)? = nil,
        onMediaServicesReset: (@Sendable () -> Void)? = nil
    ) {
        self.onInterruptionBegan = onInterruptionBegan
        self.onInterruptionEnded = onInterruptionEnded
        self.onRouteChange = onRouteChange
        self.onMediaServicesReset = onMediaServicesReset
    }
}

// MARK: - Audio Session Manager

/// Configures AVAudioSession and manages system interruptions, route changes, and port selections.
public final class AudioSessionManager: @unchecked Sendable {

    private let session: AVAudioSession
    private let logger = Logger(subsystem: "com.tamandicam", category: "AudioSessionManager")

    // MARK: - Observers

    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var resetObserver: NSObjectProtocol?

    // MARK: - Event Handlers

    public var eventHandlers = AudioSessionEventHandlers()

    // MARK: - Initialization

    public init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    deinit {
        stopObserving()
    }

    // MARK: - Session Lifecycle

    /// Configures the session with standard broadcast settings and activates it.
    public func configureAndActivate(configuration: AudioConfiguration) throws {
        do {
            var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker]
            if configuration.allowBluetooth {
                options.insert([.allowBluetooth, .allowBluetoothA2DP])
            }

            try session.setCategory(
                .playAndRecord,
                mode: .videoRecording,
                options: options
            )
        } catch {
            throw AudioError.categoryConfigurationFailed(reason: error.localizedDescription)
        }

        do {
            try session.setPreferredSampleRate(configuration.sampleRate.rawValue)
            try session.setPreferredIOBufferDuration(configuration.bufferDuration)
        } catch {
            logger.warning("Could not set preferred sample rate/buffer duration: \(error.localizedDescription)")
        }

        do {
            try session.setActive(true, options: [])
            logger.info("AVAudioSession activated successfully (Sample Rate: \(self.session.sampleRate) Hz, Channels: \(self.session.inputNumberOfChannels))")
        } catch {
            throw AudioError.sessionActivationFailed(reason: error.localizedDescription)
        }

        startObserving()
    }

    /// Deactivates the audio session.
    public func deactivate() {
        stopObserving()
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
            logger.info("AVAudioSession deactivated")
        } catch {
            logger.error("Failed to deactivate AVAudioSession: \(error.localizedDescription)")
        }
    }

    // MARK: - Port & Route Selection

    /// Selects an input port by its unique ID.
    public func selectPort(byID id: String) throws {
        guard let port = session.availableInputs?.first(where: { $0.uid == id }) else {
            throw AudioError.deviceNotFound(deviceID: id)
        }

        do {
            try session.setPreferredInput(port)
            logger.info("Preferred audio input set to: \(port.portName) (\(port.portType.rawValue))")
        } catch {
            throw AudioError.portSelectionFailed(reason: error.localizedDescription)
        }
    }

    /// Selects a specific data source and optional polar pattern on the active input port.
    public func selectDataSource(id: String?, polarPattern: AudioPolarPattern? = nil) throws {
        guard let currentPort = session.currentRoute.inputs.first else {
            throw AudioError.portSelectionFailed(reason: "No active input port")
        }

        guard let id else {
            // Nil clears preferred data source
            try? currentPort.setPreferredDataSource(nil)
            return
        }

        guard let ds = currentPort.dataSources?.first(where: { "\($0.dataSourceID)" == id }) else {
            throw AudioError.dataSourceSelectionFailed(reason: "Data source \(id) not found on port \(currentPort.portName)")
        }

        do {
            try currentPort.setPreferredDataSource(ds)
            if let pattern = polarPattern {
                let discoverer = AudioRouteDiscoverer()
                if let avPattern = discoverer.mapDomainPolarPattern(pattern) {
                    try ds.setPreferredPolarPattern(avPattern)
                }
            }
            logger.info("Selected data source: \(ds.dataSourceName) on \(currentPort.portName)")
        } catch {
            throw AudioError.dataSourceSelectionFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Hardware Gain

    /// Whether hardware gain is settable on the current input.
    public var isInputGainSettable: Bool {
        session.isInputGainSettable
    }

    /// Sets the hardware input gain if supported.
    public func setHardwareGain(_ gain: Float) throws {
        guard session.isInputGainSettable else {
            throw AudioError.gainNotSupported
        }
        let clamped = max(0.0, min(1.0, gain))
        try session.setPreferredInputGain(clamped)
        logger.info("Set hardware input gain to \(clamped)")
    }

    // MARK: - Notifications

    private func startObserving() {
        guard interruptionObserver == nil else { return }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: nil
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: nil
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }

        resetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: session,
            queue: nil
        ) { [weak self] _ in
            self?.logger.warning("Media services were reset notification received")
            self?.eventHandlers.onMediaServicesReset?()
        }
    }

    private func stopObserving() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
        }
        if let observer = resetObserver {
            NotificationCenter.default.removeObserver(observer)
            resetObserver = nil
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            logger.warning("Audio session interruption began")
            eventHandlers.onInterruptionBegan?()
        case .ended:
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            let shouldResume = options.contains(.shouldResume)
            logger.info("Audio session interruption ended (shouldResume: \(shouldResume))")
            eventHandlers.onInterruptionEnded?(shouldResume)
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        logger.info("Audio route change detected: \(String(describing: reason))")
        eventHandlers.onRouteChange?(reason)
    }
}
