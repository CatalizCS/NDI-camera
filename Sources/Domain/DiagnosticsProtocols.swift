// DiagnosticsProtocols.swift
// Domain — Protocol boundaries for the diagnostics subsystem.

import Foundation

// MARK: - Metrics Providing

/// Provides real-time and snapshot diagnostic metrics.
public protocol MetricsProviding: Sendable {
    /// Returns the latest diagnostics snapshot.
    func currentSnapshot() async -> DiagnosticsSnapshot

    /// Returns per-stage pipeline metrics.
    func pipelineMetrics() async -> [PipelineMetrics]

    /// Records a dropped frame event.
    func recordDroppedFrame() async

    /// Records a sent frame event.
    func recordSentFrame() async

    /// Updates the current capture FPS measurement.
    func updateCaptureFPS(_ fps: Double) async

    /// Updates the current output FPS measurement.
    func updateOutputFPS(_ fps: Double) async

    /// Updates video queue depth.
    func updateVideoQueueDepth(_ depth: Int) async

    /// Updates audio queue depth.
    func updateAudioQueueDepth(_ depth: Int) async
}

// MARK: - Diagnostics Exporting

/// Exports diagnostics data as JSON (sanitized — no secrets).
public protocol DiagnosticsExporting: Sendable {
    /// Exports current diagnostics as JSON data.
    func exportJSON() async throws -> Data

    /// Exports current diagnostics as a human-readable string.
    func exportReadable() async -> String
}
