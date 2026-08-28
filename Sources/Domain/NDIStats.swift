// NDIStats.swift
// Domain — Real-time performance, transmission statistics, and telemetry for NDI sending.

import Foundation

// MARK: - NDI Stats

/// Snapshot of transmission statistics and sender health metrics.
public struct NDIStats: Sendable, Hashable, Codable {

    /// Total count of video frames successfully submitted to the NDI network runtime.
    public let totalVideoFramesSent: Int

    /// Total count of video frames dropped due to network or buffer backpressure.
    public let totalVideoFramesDropped: Int

    /// Total count of audio buffer packets sent.
    public let totalAudioFramesSent: Int

    /// Instantaneous measured transmission bitrate in Megabits per second (Mbps).
    public let currentBitrateMbps: Double

    /// Instantaneous actual sender output frame rate in FPS.
    public let actualFPS: Double

    /// Current connection tally state received from remote switchers.
    public let tally: NDITally

    /// Number of active connected receivers subscribing to this NDI source.
    public let connectedReceiversCount: Int

    public init(
        totalVideoFramesSent: Int = 0,
        totalVideoFramesDropped: Int = 0,
        totalAudioFramesSent: Int = 0,
        currentBitrateMbps: Double = 0.0,
        actualFPS: Double = 0.0,
        tally: NDITally = .off,
        connectedReceiversCount: Int = 0
    ) {
        self.totalVideoFramesSent = totalVideoFramesSent
        self.totalVideoFramesDropped = totalVideoFramesDropped
        self.totalAudioFramesSent = totalAudioFramesSent
        self.currentBitrateMbps = currentBitrateMbps
        self.actualFPS = actualFPS
        self.tally = tally
        self.connectedReceiversCount = connectedReceiversCount
    }
}
