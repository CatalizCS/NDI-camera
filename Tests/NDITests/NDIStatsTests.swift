// NDIStatsTests.swift
// NDITests — Unit tests for NDIStatisticsCollector bitrate and FPS calculations.

import Testing
import Foundation
@testable import NDI
@testable import Domain

@Suite("NDIStatisticsCollector")
struct NDIStatisticsCollectorTests {

    @Test("Calculates actual FPS from recorded frame timestamps")
    func fpsCalculation() async {
        let collector = NDIStatisticsCollector()
        let baseTime = 100.0

        for i in 0..<30 {
            let t = baseTime + (Double(i) / 30.0)
            await collector.recordVideoFrame(bytes: 1_500_000, timestamp: t)
        }

        let snapshot = await collector.snapshot()
        #expect(snapshot.totalVideoFramesSent == 30)
        #expect(abs(snapshot.actualFPS - 30.0) < 1.5)
        #expect(snapshot.currentBitrateMbps > 0)
    }

    @Test("Tracks tally updates and dropped frames")
    func tallyAndDropTracking() async {
        let collector = NDIStatisticsCollector()
        await collector.updateTally(.program)
        await collector.recordVideoDrop()
        await collector.recordAudioBuffer()

        let snapshot = await collector.snapshot()
        #expect(snapshot.tally.inProgram)
        #expect(snapshot.totalVideoFramesDropped == 1)
        #expect(snapshot.totalAudioFramesSent == 1)
    }

    @Test("Reset clears all rolling data and counters")
    func resetClearsData() async {
        let collector = NDIStatisticsCollector()
        await collector.recordVideoFrame()
        await collector.updateTally(.preview)
        await collector.reset()

        let snapshot = await collector.snapshot()
        #expect(snapshot.totalVideoFramesSent == 0)
        #expect(!snapshot.tally.inPreview)
    }
}
