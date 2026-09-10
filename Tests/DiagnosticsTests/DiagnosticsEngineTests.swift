// DiagnosticsEngineTests.swift
// Tests for diagnostics engine and metrics collection.

import Testing
import Foundation
@testable import Diagnostics
@testable import Domain

@Suite("Diagnostics Engine Tests")
struct DiagnosticsEngineTests {

    @Test("Initial snapshot — all zeros")
    func testInitialSnapshot() async {
        let engine = DiagnosticsEngine()
        let snapshot = await engine.currentSnapshot()
        #expect(snapshot.captureFPS == 0)
        #expect(snapshot.outputFPS == 0)
        #expect(snapshot.droppedFrames == 0)
        #expect(snapshot.videoQueueDepth == 0)
        #expect(snapshot.audioQueueDepth == 0)
        #expect(snapshot.thermalState == .nominal)
    }

    @Test("Update FPS metrics")
    func testUpdateFPS() async {
        let engine = DiagnosticsEngine()
        await engine.updateCaptureFPS(59.94)
        await engine.updateOutputFPS(59.94)

        let snapshot = await engine.currentSnapshot()
        #expect(snapshot.captureFPS == 59.94)
        #expect(snapshot.outputFPS == 59.94)
    }

    @Test("Record dropped frames")
    func testRecordDroppedFrames() async {
        let engine = DiagnosticsEngine()
        await engine.recordDroppedFrame()
        await engine.recordDroppedFrame()
        await engine.recordDroppedFrame()

        let snapshot = await engine.currentSnapshot()
        #expect(snapshot.droppedFrames == 3)
    }

    @Test("Update queue depths")
    func testUpdateQueueDepths() async {
        let engine = DiagnosticsEngine()
        await engine.updateVideoQueueDepth(2)
        await engine.updateAudioQueueDepth(1)

        let snapshot = await engine.currentSnapshot()
        #expect(snapshot.videoQueueDepth == 2)
        #expect(snapshot.audioQueueDepth == 1)
    }

    @Test("Update format and route info")
    func testUpdateFormatInfo() async {
        let engine = DiagnosticsEngine()
        await engine.updateActiveFormat("1920x1080@60")
        await engine.updateActiveAudioRoute("Built-In Microphone")

        let snapshot = await engine.currentSnapshot()
        #expect(snapshot.activeFormat == "1920x1080@60")
        #expect(snapshot.activeAudioRoute == "Built-In Microphone")
    }

    @Test("Pipeline timing recording")
    func testPipelineTimings() async {
        let engine = DiagnosticsEngine()
        await engine.recordPipelineTiming(stage: "frame-capture", latencyMs: 0.5)
        await engine.recordPipelineTiming(stage: "frame-capture", latencyMs: 1.5)
        await engine.recordPipelineTiming(stage: "ndi-send", latencyMs: 3.0)

        let metrics = await engine.pipelineMetrics()
        #expect(metrics.count == 2)

        let captureMetrics = metrics.first(where: { $0.stageName == "frame-capture" })
        #expect(captureMetrics != nil)
        #expect(captureMetrics?.sampleCount == 2)
        #expect(captureMetrics?.averageLatencyMs == 1.0)
        #expect(captureMetrics?.maxLatencyMs == 1.5)
    }

    @Test("Reset clears all metrics")
    func testReset() async {
        let engine = DiagnosticsEngine()
        await engine.updateCaptureFPS(60)
        await engine.recordDroppedFrame()
        await engine.updateVideoQueueDepth(3)

        await engine.reset()

        let snapshot = await engine.currentSnapshot()
        #expect(snapshot.captureFPS == 0)
        #expect(snapshot.droppedFrames == 0)
        #expect(snapshot.videoQueueDepth == 0)
    }

    @Test("Export JSON — valid JSON data")
    func testExportJSON() async throws {
        let engine = DiagnosticsEngine()
        await engine.updateCaptureFPS(59.94)

        let jsonData = try await engine.exportJSON()
        let decoded = try JSONDecoder().decode(DiagnosticsSnapshot.self, from: jsonData)
        #expect(decoded.captureFPS == 59.94)
    }

    @Test("Export readable — contains key fields")
    func testExportReadable() async {
        let engine = DiagnosticsEngine()
        await engine.updateCaptureFPS(59.94)
        await engine.updateActiveFormat("1920x1080@60")

        let text = await engine.exportReadable()
        #expect(text.contains("TamaNDI Diagnostics"))
        #expect(text.contains("59.9"))
        #expect(text.contains("1920x1080@60"))
    }

    @Test("Memory footprint — returns non-negative value")
    func testMemoryFootprint() async {
        let engine = DiagnosticsEngine()
        let snapshot = await engine.currentSnapshot()
        #expect(snapshot.memoryFootprintMB >= 0)
    }
}
