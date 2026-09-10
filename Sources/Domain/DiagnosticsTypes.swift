// DiagnosticsTypes.swift
// Domain — Types for the diagnostics and metrics subsystem.

import Foundation

// MARK: - Thermal State

/// Mapped thermal state from ProcessInfo.
public enum ThermalState: String, Sendable, Codable, Hashable, CaseIterable {
    case nominal
    case fair
    case serious
    case critical
}

// MARK: - Diagnostics Snapshot

/// Point-in-time system metrics snapshot.
public struct DiagnosticsSnapshot: Sendable, Codable, Hashable {
    public let timestamp: Date
    public let captureFPS: Double
    public let outputFPS: Double
    public let droppedFrames: UInt64
    public let videoQueueDepth: Int
    public let audioQueueDepth: Int
    public let estimatedBitrateMbps: Double
    public let memoryFootprintMB: Double
    public let thermalState: ThermalState
    public let activeFormat: String?
    public let activeAudioRoute: String?
    public let networkInterface: String?

    public init(
        timestamp: Date = Date(),
        captureFPS: Double = 0,
        outputFPS: Double = 0,
        droppedFrames: UInt64 = 0,
        videoQueueDepth: Int = 0,
        audioQueueDepth: Int = 0,
        estimatedBitrateMbps: Double = 0,
        memoryFootprintMB: Double = 0,
        thermalState: ThermalState = .nominal,
        activeFormat: String? = nil,
        activeAudioRoute: String? = nil,
        networkInterface: String? = nil
    ) {
        self.timestamp = timestamp
        self.captureFPS = captureFPS
        self.outputFPS = outputFPS
        self.droppedFrames = droppedFrames
        self.videoQueueDepth = videoQueueDepth
        self.audioQueueDepth = audioQueueDepth
        self.estimatedBitrateMbps = estimatedBitrateMbps
        self.memoryFootprintMB = memoryFootprintMB
        self.thermalState = thermalState
        self.activeFormat = activeFormat
        self.activeAudioRoute = activeAudioRoute
        self.networkInterface = networkInterface
    }
}

// MARK: - Pipeline Metrics

/// Per-pipeline-stage timing measurements.
public struct PipelineMetrics: Sendable, Codable, Hashable {
    public let stageName: String
    public let averageLatencyMs: Double
    public let maxLatencyMs: Double
    public let sampleCount: UInt64

    public init(stageName: String, averageLatencyMs: Double = 0, maxLatencyMs: Double = 0, sampleCount: UInt64 = 0) {
        self.stageName = stageName
        self.averageLatencyMs = averageLatencyMs
        self.maxLatencyMs = maxLatencyMs
        self.sampleCount = sampleCount
    }
}
