// AudioProtocols.swift
// Domain — Protocol boundaries and types for the audio subsystem.

import Foundation
import CoreMedia
import AVFoundation

// MARK: - Audio State

/// Observable snapshot of the current audio subsystem state.
public struct AudioState: Sendable, Hashable {
    public let isRunning: Bool
    public let isMuted: Bool
    public let gain: Float
    public let isHardwareGainSupported: Bool
    public let selectedDevice: AudioInputDevice?
    public let selectedDataSource: AudioDataSource?
    public let sampleRate: AudioSampleRate
    public let channelLayout: AudioChannelLayout
    public let sessionState: StreamState

    public init(
        isRunning: Bool = false,
        isMuted: Bool = false,
        gain: Float = 1.0,
        isHardwareGainSupported: Bool = false,
        selectedDevice: AudioInputDevice? = nil,
        selectedDataSource: AudioDataSource? = nil,
        sampleRate: AudioSampleRate = .rate48000,
        channelLayout: AudioChannelLayout = .stereo,
        sessionState: StreamState = .idle
    ) {
        self.isRunning = isRunning
        self.isMuted = isMuted
        self.gain = gain
        self.isHardwareGainSupported = isHardwareGainSupported
        self.selectedDevice = selectedDevice
        self.selectedDataSource = selectedDataSource
        self.sampleRate = sampleRate
        self.channelLayout = channelLayout
        self.sessionState = sessionState
    }
}

// MARK: - Audio Frame

/// A captured linear PCM audio frame with sample-accurate synchronization metadata.
public struct AudioFrame: Sendable {
    /// CMSampleBuffer containing linear PCM audio data.
    public let sampleBuffer: CMSampleBuffer

    /// Presentation timestamp aligned to the capture/system clock.
    public let timestamp: CMTime

    /// Microsecond timecode referenced to host time (mach_absolute_time).
    public let timecodeMicros: Int64

    /// Sampling frequency in Hertz (e.g. 48000.0).
    public let sampleRate: Double

    /// Number of audio channels (e.g. 1 for mono, 2 for stereo).
    public let channelCount: Int

    /// Number of audio sample frames contained in this buffer.
    public let frameCount: Int

    public init(
        sampleBuffer: CMSampleBuffer,
        timestamp: CMTime,
        timecodeMicros: Int64,
        sampleRate: Double,
        channelCount: Int,
        frameCount: Int
    ) {
        self.sampleBuffer = sampleBuffer
        self.timestamp = timestamp
        self.timecodeMicros = timecodeMicros
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
    }
}

// MARK: - Audio Frame Consuming

/// Protocol for components that ingest raw audio frames (such as NDIAudioSender).
public protocol AudioFrameConsuming: Sendable {
    /// Receives a captured, synchronized audio frame.
    func receiveAudioFrame(_ frame: AudioFrame) async
}

// MARK: - Audio Controlling

/// Controls audio hardware, session lifecycle, routing, gain, and mute.
public protocol AudioControlling: Sendable {
    /// Starts the audio session and real-time capture pipeline.
    func start() async throws

    /// Stops audio capture and releases audio resources.
    func stop() async

    /// Selects an audio input device (built-in, USB, Bluetooth).
    func selectDevice(_ device: AudioInputDevice) async throws

    /// Selects a specific micro-capsule or polar pattern data source on the current port.
    func selectDataSource(_ dataSource: AudioDataSource?) async throws

    /// Configures the capture sample rate.
    func setSampleRate(_ sampleRate: AudioSampleRate) async throws

    /// Configures the active channel layout.
    func setChannelLayout(_ layout: AudioChannelLayout) async throws

    /// Sets input gain (0.0 to 1.0 hardware gain where supported, or digital gain multiplier 0.0 to 2.0+).
    func setGain(_ gain: Float) async throws

    /// Sets mute state (silence injection while maintaining timestamp continuity).
    func setMuted(_ isMuted: Bool) async
}

// MARK: - Audio Capability Providing

/// Dynamically discovers available audio inputs, routes, supported formats, and metrics.
public protocol AudioCapabilityProviding: Sendable {
    /// Lists all currently connected audio input devices.
    func availableInputDevices() async -> [AudioInputDevice]

    /// Returns the currently active audio input device.
    func currentDevice() async -> AudioInputDevice?

    /// Lists supported sample rates for a specific device.
    func supportedSampleRates(for device: AudioInputDevice) async -> [AudioSampleRate]

    /// Lists supported channel counts for a specific device.
    func supportedChannelCounts(for device: AudioInputDevice) async -> [Int]

    /// Whether hardware input gain is settable on the current input port.
    func isHardwareGainSettable() async -> Bool

    /// Returns an immutable snapshot of current audio state.
    func currentState() async -> AudioState

    /// Returns the latest peak and RMS level metering snapshot.
    func currentLevels() async -> AudioLevelsSnapshot
}
