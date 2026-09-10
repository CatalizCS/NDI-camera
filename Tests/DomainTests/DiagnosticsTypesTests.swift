// DiagnosticsTypesTests.swift

import Testing
@testable import Domain

@Suite("Diagnostics Types Tests")
struct DiagnosticsTypesTests {

    @Test("ThermalState all cases")
    func testThermalStateAllCases() {
        #expect(ThermalState.allCases.count == 4)
    }

    @Test("ThermalState Codable roundtrip")
    func testThermalStateCodable() throws {
        let original = ThermalState.serious
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThermalState.self, from: data)
        #expect(decoded == original)
    }

    @Test("DiagnosticsSnapshot defaults")
    func testSnapshotDefaults() {
        let snapshot = DiagnosticsSnapshot()
        #expect(snapshot.captureFPS == 0)
        #expect(snapshot.outputFPS == 0)
        #expect(snapshot.droppedFrames == 0)
        #expect(snapshot.videoQueueDepth == 0)
        #expect(snapshot.thermalState == .nominal)
    }

    @Test("DiagnosticsSnapshot Codable roundtrip")
    func testSnapshotCodable() throws {
        let original = DiagnosticsSnapshot(
            captureFPS: 59.94,
            outputFPS: 59.94,
            droppedFrames: 12,
            videoQueueDepth: 2,
            thermalState: .fair,
            activeFormat: "1920x1080@60"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DiagnosticsSnapshot.self, from: data)
        #expect(decoded == original)
    }

    @Test("PipelineMetrics initialization")
    func testPipelineMetrics() {
        let metrics = PipelineMetrics(stageName: "frame-capture", averageLatencyMs: 0.5, maxLatencyMs: 2.1, sampleCount: 1000)
        #expect(metrics.stageName == "frame-capture")
        #expect(metrics.averageLatencyMs == 0.5)
    }

    @Test("PipelineMetrics Codable roundtrip")
    func testPipelineMetricsCodable() throws {
        let original = PipelineMetrics(stageName: "ndi-send", averageLatencyMs: 3.2, maxLatencyMs: 8.1, sampleCount: 500)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PipelineMetrics.self, from: data)
        #expect(decoded == original)
    }
}
