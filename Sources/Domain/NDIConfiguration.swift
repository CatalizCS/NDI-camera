// NDIConfiguration.swift
// Domain — Configuration descriptor for NDI broadcast sender instances.

import Foundation

// MARK: - NDI Video Standard Format

/// Video standard/format hinting for NDI sender stream parameters.
public enum NDIVideoFormat: String, Sendable, Codable, CaseIterable, Hashable {
    case bgra
    case uyvy
    case nv12
    case p216 // 16-bit HDR
}

// MARK: - NDI Configuration

/// Immutable configuration parameters for creating and running an NDI sender stream.
public struct NDIConfiguration: Sendable, Hashable, Codable {

    /// The advertised NDI source name (e.g., "TamaNDI Camera 1").
    public var sourceName: String

    /// Optional NDI discovery groups (empty for public default group).
    public var groups: [String]

    /// Target video resolution for output frames.
    public var targetResolution: Resolution

    /// Target frame rate in FPS (e.g. 30.0, 60.0).
    public var targetFPS: Double

    /// Color format for video frame payloads.
    public var videoFormat: NDIVideoFormat

    /// Audio sample rate in Hz (default 48000).
    public var audioSampleRate: Int

    /// Audio channel count (default 2 for stereo).
    public var audioChannelCount: Int

    /// Whether video frames should be clocked to system time by the NDI runtime.
    public var isClockVideo: Bool

    /// Whether audio samples should be clocked to system time by the NDI runtime.
    public var isClockAudio: Bool

    public init(
        sourceName: String = "TamaNDI-Camera",
        groups: [String] = [],
        targetResolution: Resolution = Resolution(width: 1920, height: 1080),
        targetFPS: Double = 30.0,
        videoFormat: NDIVideoFormat = .bgra,
        audioSampleRate: Int = 48000,
        audioChannelCount: Int = 2,
        isClockVideo: Bool = true,
        isClockAudio: Bool = true
    ) {
        self.sourceName = sourceName
        self.groups = groups
        self.targetResolution = targetResolution
        self.targetFPS = targetFPS
        self.videoFormat = videoFormat
        self.audioSampleRate = audioSampleRate
        self.audioChannelCount = audioChannelCount
        self.isClockVideo = isClockVideo
        self.isClockAudio = isClockAudio
    }
}
