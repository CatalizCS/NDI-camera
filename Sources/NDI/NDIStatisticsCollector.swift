// NDIStatisticsCollector.swift
// NDI — Performance metrics, bitrate estimation, and real-time statistics collector for NDI sending.

import Foundation
import Domain
import QuartzCore

// MARK: - NDI Statistics Collector

/// Actor tracking transmission performance metrics, frame rates, and network telemetry for NDI.
public actor NDIStatisticsCollector {

    // MARK: - State

    private var tally: NDITally = .off
    private var connectedReceivers: Int = 0

    /// Rolling window of recent video frame timestamps.
    private var frameTimestamps: [Double] = []

    /// Rolling window of sent payload byte counts for bitrate calculation.
    private var byteSamples: [(timestamp: Double, bytes: Int)] = []

    private var cumulativeVideoSent: Int = 0
    private var cumulativeVideoDropped: Int = 0
    private var cumulativeAudioSent: Int = 0

    private let maxHistoryEntries = 30

    // MARK: - Initialization

    public init() {}

    // MARK: - Recording

    /// Records a successfully sent video frame with estimated payload byte size.
    public func recordVideoFrame(bytes: Int = 2_000_000, timestamp: Double = CACurrentMediaTime()) {
        cumulativeVideoSent += 1
        frameTimestamps.append(timestamp)
        byteSamples.append((timestamp: timestamp, bytes: bytes))

        if frameTimestamps.count > maxHistoryEntries {
            frameTimestamps.removeFirst(frameTimestamps.count - maxHistoryEntries)
        }
        if byteSamples.count > maxHistoryEntries {
            byteSamples.removeFirst(byteSamples.count - maxHistoryEntries)
        }
    }

    /// Records a dropped video frame due to backpressure.
    public func recordVideoDrop() {
        cumulativeVideoDropped += 1
    }

    /// Records an audio buffer transmission.
    public func recordAudioBuffer() {
        cumulativeAudioSent += 1
    }

    /// Updates connection tally status.
    public func updateTally(_ tally: NDITally) {
        self.tally = tally
    }

    /// Updates connected receivers count.
    public func updateConnectedReceivers(_ count: Int) {
        self.connectedReceivers = count
    }

    /// Resets all statistics counters.
    public func reset() {
        cumulativeVideoSent = 0
        cumulativeVideoDropped = 0
        cumulativeAudioSent = 0
        frameTimestamps.removeAll()
        byteSamples.removeAll()
        tally = .off
        connectedReceivers = 0
    }

    // MARK: - Snapshot

    /// Returns the current NDIStats snapshot.
    public func snapshot() -> NDIStats {
        var actualFPS = 0.0
        if frameTimestamps.count >= 2, let first = frameTimestamps.first, let last = frameTimestamps.last {
            let duration = last - first
            if duration > 0 {
                actualFPS = Double(frameTimestamps.count - 1) / duration
            }
        }

        var bitrateMbps = 0.0
        if byteSamples.count >= 2, let first = byteSamples.first, let last = byteSamples.last {
            let duration = last.timestamp - first.timestamp
            if duration > 0 {
                let totalBytes = byteSamples.reduce(0) { $0 + $1.bytes }
                let bits = Double(totalBytes * 8)
                bitrateMbps = (bits / duration) / 1_000_000.0
            }
        }

        return NDIStats(
            totalVideoFramesSent: cumulativeVideoSent,
            totalVideoFramesDropped: cumulativeVideoDropped,
            totalAudioFramesSent: cumulativeAudioSent,
            currentBitrateMbps: (bitrateMbps * 10).rounded() / 10,
            actualFPS: (actualFPS * 10).rounded() / 10,
            tally: tally,
            connectedReceiversCount: connectedReceivers
        )
    }
}
