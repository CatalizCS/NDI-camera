// MetricsCollector.swift
// Diagnostics — Thread-safe metrics collection for pipeline stages.

import Foundation
import Domain
#if canImport(os)
import os
#endif

/// Collects real-time metrics from pipeline stages.
/// Uses thread-safe mutable state for counters and measurements.
///
/// Note: This type is designed to be used within the actor-isolated DiagnosticsEngine.
/// Direct cross-thread access is prevented by the actor boundary.
public final class MetricsCollector: Sendable {

    // MARK: - Atomic-like State (protected by DiagnosticsEngine actor)

    // Use nonisolated(unsafe) for mutable state that is protected by the owning actor
    nonisolated(unsafe) private var _sentFrames: UInt64 = 0
    nonisolated(unsafe) private var _droppedFrames: UInt64 = 0
    nonisolated(unsafe) private var _captureFPS: Double = 0
    nonisolated(unsafe) private var _outputFPS: Double = 0
    nonisolated(unsafe) private var _videoQueueDepth: Int = 0
    nonisolated(unsafe) private var _audioQueueDepth: Int = 0
    nonisolated(unsafe) private var _estimatedBitrateMbps: Double = 0
    nonisolated(unsafe) private var _activeFormat: String? = nil
    nonisolated(unsafe) private var _activeAudioRoute: String? = nil
    nonisolated(unsafe) private var _networkInterface: String? = nil
    nonisolated(unsafe) private var _pipelineTimings: [String: PipelineTimingAccumulator] = [:]

    // MARK: - Init

    public init() {}

    // MARK: - Frame Counters

    func incrementSentFrames() {
        _sentFrames += 1
    }

    func incrementDroppedFrames() {
        _droppedFrames += 1
    }

    // MARK: - FPS

    func setCaptureFPS(_ fps: Double) {
        _captureFPS = fps
    }

    func setOutputFPS(_ fps: Double) {
        _outputFPS = fps
    }

    // MARK: - Queue Depths

    func setVideoQueueDepth(_ depth: Int) {
        _videoQueueDepth = depth
    }

    func setAudioQueueDepth(_ depth: Int) {
        _audioQueueDepth = depth
    }

    // MARK: - Additional Metrics

    func setActiveFormat(_ format: String?) {
        _activeFormat = format
    }

    func setActiveAudioRoute(_ route: String?) {
        _activeAudioRoute = route
    }

    func setNetworkInterface(_ interface: String?) {
        _networkInterface = interface
    }

    // MARK: - Pipeline Timing

    func recordTiming(stage: String, latencyMs: Double) {
        if _pipelineTimings[stage] == nil {
            _pipelineTimings[stage] = PipelineTimingAccumulator()
        }
        _pipelineTimings[stage]?.record(latencyMs)
    }

    func allPipelineMetrics() -> [PipelineMetrics] {
        _pipelineTimings.map { key, acc in
            PipelineMetrics(
                stageName: key,
                averageLatencyMs: acc.average,
                maxLatencyMs: acc.max,
                sampleCount: acc.count
            )
        }
    }

    // MARK: - System Metrics

    /// Memory footprint in MB using task_info.
    func memoryFootprintMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024)
        }
        return 0
    }

    /// Current thermal state mapped to our domain enum.
    func thermalState() -> ThermalState {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }

    // MARK: - Snapshot

    func snapshot() -> DiagnosticsSnapshot {
        DiagnosticsSnapshot(
            timestamp: Date(),
            captureFPS: _captureFPS,
            outputFPS: _outputFPS,
            droppedFrames: _droppedFrames,
            videoQueueDepth: _videoQueueDepth,
            audioQueueDepth: _audioQueueDepth,
            estimatedBitrateMbps: _estimatedBitrateMbps,
            memoryFootprintMB: memoryFootprintMB(),
            thermalState: thermalState(),
            activeFormat: _activeFormat,
            activeAudioRoute: _activeAudioRoute,
            networkInterface: _networkInterface
        )
    }

    // MARK: - Reset

    func reset() {
        _sentFrames = 0
        _droppedFrames = 0
        _captureFPS = 0
        _outputFPS = 0
        _videoQueueDepth = 0
        _audioQueueDepth = 0
        _estimatedBitrateMbps = 0
        _activeFormat = nil
        _activeAudioRoute = nil
        _networkInterface = nil
        _pipelineTimings.removeAll()
    }
}

// MARK: - Pipeline Timing Accumulator

/// Accumulates timing measurements for a pipeline stage.
final class PipelineTimingAccumulator: Sendable {
    nonisolated(unsafe) private var _sum: Double = 0
    nonisolated(unsafe) private var _max: Double = 0
    nonisolated(unsafe) private var _count: UInt64 = 0

    init() {}

    func record(_ latencyMs: Double) {
        _sum += latencyMs
        _count += 1
        if latencyMs > _max {
            _max = latencyMs
        }
    }

    var average: Double {
        _count > 0 ? _sum / Double(_count) : 0
    }

    var max: Double { _max }
    var count: UInt64 { _count }
}
