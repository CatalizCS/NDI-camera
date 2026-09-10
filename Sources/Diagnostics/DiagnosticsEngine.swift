// DiagnosticsEngine.swift
// Diagnostics — Actor-isolated diagnostics engine collecting metrics from all pipeline stages.

import Foundation
import Domain

/// Actor-isolated diagnostics engine.
/// Collects metrics from all pipeline stages, generates periodic snapshots,
/// and exports sanitized diagnostics JSON.
public actor DiagnosticsEngine: MetricsProviding, DiagnosticsExporting {

    // MARK: - State

    private let metricsCollector: MetricsCollector

    // MARK: - Init

    public init() {
        self.metricsCollector = MetricsCollector()
    }

    // MARK: - MetricsProviding

    public func currentSnapshot() -> DiagnosticsSnapshot {
        metricsCollector.snapshot()
    }

    public func pipelineMetrics() -> [PipelineMetrics] {
        metricsCollector.allPipelineMetrics()
    }

    public func recordDroppedFrame() {
        metricsCollector.incrementDroppedFrames()
    }

    public func recordSentFrame() {
        metricsCollector.incrementSentFrames()
    }

    public func updateCaptureFPS(_ fps: Double) {
        metricsCollector.setCaptureFPS(fps)
    }

    public func updateOutputFPS(_ fps: Double) {
        metricsCollector.setOutputFPS(fps)
    }

    public func updateVideoQueueDepth(_ depth: Int) {
        metricsCollector.setVideoQueueDepth(depth)
    }

    public func updateAudioQueueDepth(_ depth: Int) {
        metricsCollector.setAudioQueueDepth(depth)
    }

    // MARK: - Additional Metrics

    /// Update the active format description string.
    public func updateActiveFormat(_ format: String?) {
        metricsCollector.setActiveFormat(format)
    }

    /// Update the active audio route description string.
    public func updateActiveAudioRoute(_ route: String?) {
        metricsCollector.setActiveAudioRoute(route)
    }

    /// Update the network interface info.
    public func updateNetworkInterface(_ interface: String?) {
        metricsCollector.setNetworkInterface(interface)
    }

    /// Record a pipeline stage timing measurement.
    public func recordPipelineTiming(stage: String, latencyMs: Double) {
        metricsCollector.recordTiming(stage: stage, latencyMs: latencyMs)
    }

    /// Reset all counters and metrics.
    public func reset() {
        metricsCollector.reset()
    }

    // MARK: - DiagnosticsExporting

    public func exportJSON() throws -> Data {
        let snapshot = metricsCollector.snapshot()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    public func exportReadable() -> String {
        let snapshot = metricsCollector.snapshot()
        var lines: [String] = []
        lines.append("=== TamaNDI Diagnostics ===")
        lines.append("Timestamp: \(snapshot.timestamp)")
        lines.append("Capture FPS: \(String(format: "%.1f", snapshot.captureFPS))")
        lines.append("Output FPS: \(String(format: "%.1f", snapshot.outputFPS))")
        lines.append("Dropped Frames: \(snapshot.droppedFrames)")
        lines.append("Video Queue Depth: \(snapshot.videoQueueDepth)")
        lines.append("Audio Queue Depth: \(snapshot.audioQueueDepth)")
        lines.append("Bitrate: \(String(format: "%.1f", snapshot.estimatedBitrateMbps)) Mbps")
        lines.append("Memory: \(String(format: "%.1f", snapshot.memoryFootprintMB)) MB")
        lines.append("Thermal: \(snapshot.thermalState.rawValue)")
        if let format = snapshot.activeFormat {
            lines.append("Format: \(format)")
        }
        if let route = snapshot.activeAudioRoute {
            lines.append("Audio Route: \(route)")
        }
        if let net = snapshot.networkInterface {
            lines.append("Network: \(net)")
        }
        lines.append("===========================")
        return lines.joined(separator: "\n")
    }
}
