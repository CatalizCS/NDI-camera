// MultiCamDiagnostics.swift
// MultiCam — Performance metrics, frame rate tracking, sync drift, and resource diagnostics.

import Foundation
import CoreMedia
import Domain
import os

// MARK: - MultiCam Telemetry Snapshot

/// Observable metrics snapshot for telemetry, remote monitoring, and UI diagnostic overlays.
public struct MultiCamTelemetry: Sendable, Hashable {
    /// Active camera mode.
    public let mode: CameraMode

    /// Number of active camera slots.
    public let activeSlotsCount: Int

    /// Instantaneous measured FPS per slot.
    public let perSlotFPS: [MultiCamSlot: Double]

    /// Cumulative dropped frame count per slot.
    public let perSlotDrops: [MultiCamSlot: Int]

    /// Average synchronization drift in milliseconds across camera feeds.
    public let averageSyncDriftMs: Double

    /// Total number of composite frames generated.
    public let totalCompositeFrames: Int

    /// Current aggregate hardware resource cost score (0.0 to 1.0).
    public let hardwareCost: Float

    /// Whether thermal or resource pressure is currently causing throttled performance.
    public let isThrottled: Bool

    public init(
        mode: CameraMode = .single,
        activeSlotsCount: Int = 1,
        perSlotFPS: [MultiCamSlot: Double] = [:],
        perSlotDrops: [MultiCamSlot: Int] = [:],
        averageSyncDriftMs: Double = 0.0,
        totalCompositeFrames: Int = 0,
        hardwareCost: Float = 0.0,
        isThrottled: Bool = false
    ) {
        self.mode = mode
        self.activeSlotsCount = activeSlotsCount
        self.perSlotFPS = perSlotFPS
        self.perSlotDrops = perSlotDrops
        self.averageSyncDriftMs = averageSyncDriftMs
        self.totalCompositeFrames = totalCompositeFrames
        self.hardwareCost = hardwareCost
        self.isThrottled = isThrottled
    }
}

// MARK: - Diagnostics Collector

/// Actor collecting and computing real-time diagnostic performance metrics for multi-camera streams.
public actor MultiCamDiagnosticsCollector {

    // MARK: - State

    private var mode: CameraMode = .single
    private var hardwareCost: Float = 0.0
    private var isThrottled: Bool = false

    /// Rolling window of recent frame arrival timestamps for calculating FPS.
    private var frameTimestamps: [MultiCamSlot: [Double]] = [:]

    /// Cumulative drop counter per slot.
    private var dropCounters: [MultiCamSlot: Int] = [:]

    /// Total composite frames counter.
    private var compositeFramesCount: Int = 0

    /// Rolling sync drift measurements in milliseconds.
    private var syncDriftHistory: [Double] = []

    private let maxHistoryEntries = 30

    // MARK: - Initialization

    public init() {}

    // MARK: - Recording

    /// Records a delivered frame for a given slot.
    public func recordFrame(for slot: MultiCamSlot, at timestamp: Double = CACurrentMediaTime()) {
        var timestamps = frameTimestamps[slot] ?? []
        timestamps.append(timestamp)
        if timestamps.count > maxHistoryEntries {
            timestamps.removeFirst(timestamps.count - maxHistoryEntries)
        }
        frameTimestamps[slot] = timestamps
    }

    /// Records a dropped frame for a slot.
    public func recordDrop(for slot: MultiCamSlot) {
        dropCounters[slot, default: 0] += 1
    }

    /// Records a successful composite frame with measured sync drift.
    public func recordCompositeFrame(driftMs: Double) {
        compositeFramesCount += 1
        syncDriftHistory.append(driftMs)
        if syncDriftHistory.count > maxHistoryEntries {
            syncDriftHistory.removeFirst(syncDriftHistory.count - maxHistoryEntries)
        }
    }

    /// Updates configuration state.
    public func updateState(mode: CameraMode, hardwareCost: Float, isThrottled: Bool) {
        self.mode = mode
        self.hardwareCost = hardwareCost
        self.isThrottled = isThrottled
    }

    /// Resets all counters and rolling history.
    public func reset() {
        frameTimestamps.removeAll()
        dropCounters.removeAll()
        compositeFramesCount = 0
        syncDriftHistory.removeAll()
    }

    // MARK: - Snapshot

    /// Returns the current telemetry snapshot.
    public func snapshot() -> MultiCamTelemetry {
        var fpsMap: [MultiCamSlot: Double] = [:]
        for (slot, timestamps) in frameTimestamps {
            if timestamps.count >= 2, let first = timestamps.first, let last = timestamps.last {
                let duration = last - first
                if duration > 0 {
                    let fps = Double(timestamps.count - 1) / duration
                    fpsMap[slot] = (fps * 10).rounded() / 10
                }
            } else {
                fpsMap[slot] = 0.0
            }
        }

        let avgDrift = syncDriftHistory.isEmpty
            ? 0.0
            : (syncDriftHistory.reduce(0.0, +) / Double(syncDriftHistory.count))

        return MultiCamTelemetry(
            mode: mode,
            activeSlotsCount: frameTimestamps.keys.count,
            perSlotFPS: fpsMap,
            perSlotDrops: dropCounters,
            averageSyncDriftMs: (avgDrift * 100).rounded() / 100,
            totalCompositeFrames: compositeFramesCount,
            hardwareCost: hardwareCost,
            isThrottled: isThrottled
        )
    }
}
