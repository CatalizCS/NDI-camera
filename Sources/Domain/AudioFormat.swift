// AudioFormat.swift
// Domain — Value types for audio sample rates, channel configurations, and format descriptors.

import Foundation

// MARK: - Audio Sample Rate

/// Standard audio sample rates supported in broadcast and production.
public enum AudioSampleRate: Double, Sendable, Codable, Hashable, CaseIterable {
    /// Broadcast & NDI standard 48 kHz.
    case rate48000 = 48000.0
    /// Compact disc / legacy standard 44.1 kHz.
    case rate44100 = 44100.0
    /// High-resolution 96 kHz.
    case rate96000 = 96000.0

    public var displayName: String {
        switch self {
        case .rate48000: return "48 kHz (Broadcast)"
        case .rate44100: return "44.1 kHz (CD)"
        case .rate96000: return "96 kHz (Hi-Res)"
        }
    }

    /// Matches a floating-point frequency to the closest standard enum case.
    public static func nearest(to frequency: Double) -> AudioSampleRate {
        if frequency >= 70000 {
            return .rate96000
        } else if frequency >= 46000 {
            return .rate48000
        } else {
            return .rate44100
        }
    }
}

// MARK: - Audio Channel Layout

/// Channel topology for captured audio.
public enum AudioChannelLayout: String, Sendable, Codable, Hashable, CaseIterable {
    case mono = "mono"
    case stereo = "stereo"
    case multiChannel = "multiChannel"

    public var channelCount: Int {
        switch self {
        case .mono: return 1
        case .stereo: return 2
        case .multiChannel: return 4
        }
    }

    public var displayName: String {
        switch self {
        case .mono: return "Mono (1 Ch)"
        case .stereo: return "Stereo (2 Ch)"
        case .multiChannel: return "Multi-Channel"
        }
    }

    public static func from(channelCount: Int) -> AudioChannelLayout {
        switch channelCount {
        case 1: return .mono
        case 2: return .stereo
        default: return .multiChannel
        }
    }
}

// MARK: - Audio Configuration

/// Aggregate configuration for the active audio capture session.
public struct AudioConfiguration: Sendable, Hashable, Codable {
    /// Target sample rate (default 48000 Hz).
    public var sampleRate: AudioSampleRate
    /// Target channel layout (default stereo).
    public var channelLayout: AudioChannelLayout
    /// Preferred I/O buffer duration in seconds (e.g. 0.005 to 0.02s for 5-20ms latency).
    public var bufferDuration: Double
    /// Whether Bluetooth input routing is enabled.
    public var allowBluetooth: Bool

    public init(
        sampleRate: AudioSampleRate = .rate48000,
        channelLayout: AudioChannelLayout = .stereo,
        bufferDuration: Double = 0.01,
        allowBluetooth: Bool = true
    ) {
        self.sampleRate = sampleRate
        self.channelLayout = channelLayout
        self.bufferDuration = max(bufferDuration, 0.001)
        self.allowBluetooth = allowBluetooth
    }
}
