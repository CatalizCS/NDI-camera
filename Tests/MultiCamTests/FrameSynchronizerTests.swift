// FrameSynchronizerTests.swift
// MultiCamTests — Unit tests for FrameSynchronizer timestamp alignment, jitter tolerance, and drop recovery.

import Testing
import Foundation
import CoreMedia
import CoreVideo
@testable import MultiCam
@testable import Domain

// MARK: - Test Helpers

private func makeSampleBuffer(pts: CMTime) -> CMSampleBuffer {
    var pixelBuffer: CVPixelBuffer?
    let attrs: [CFString: Any] = [
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
    ]
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        32, 32,
        kCVPixelFormatType_32BGRA,
        attrs as CFDictionary,
        &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pb = pixelBuffer else {
        fatalError("Failed to create test pixel buffer")
    }

    var formatDesc: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pb,
        formatDescriptionOut: &formatDesc
    )
    guard let fd = formatDesc else {
        fatalError("Failed to create test format description")
    }

    var timing = CMSampleTimingInfo(
        duration: CMTime(value: 1, timescale: 30),
        presentationTimeStamp: pts,
        decodeTimeStamp: .invalid
    )

    var sampleBuffer: CMSampleBuffer?
    CMSampleBufferCreateReadyWithImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pb,
        formatDescription: fd,
        sampleTiming: &timing,
        sampleBufferOut: &sampleBuffer
    )
    guard let sb = sampleBuffer else {
        fatalError("Failed to create test sample buffer")
    }
    return sb
}

private func makeSampleFrame(slot: MultiCamSlot, timeSeconds: Double) -> MultiCamSampleFrame {
    let pts = CMTime(seconds: timeSeconds, preferredTimescale: 600)
    let sb = makeSampleBuffer(pts: pts)
    return MultiCamSampleFrame(slot: slot, cameraID: "cam-\(slot.rawValue)", sampleBuffer: sb, timestamp: pts)
}

// MARK: - Frame Synchronizer Tests

@Suite("FrameSynchronizer")
struct FrameSynchronizerTests {

    @Test("Single camera mode immediately returns synchronized frame set")
    func singleCameraMode() async {
        let synchronizer = FrameSynchronizer(activeSlots: [.primary])
        let frame = makeSampleFrame(slot: .primary, timeSeconds: 1.0)

        let result = await synchronizer.enqueue(frame)
        #expect(result != nil)
        #expect(result?.frames.count == 1)
        #expect(result?.frames[.primary]?.slot == .primary)
        #expect(result?.maxDriftMs == 0.0)
    }

    @Test("Dual camera mode matches frames within jitter tolerance")
    func dualCameraModeMatches() async {
        let synchronizer = FrameSynchronizer(
            activeSlots: [.primary, .secondary],
            toleranceWindowSeconds: 0.025 // 25ms
        )

        // Primary frame at t = 1.000s
        let fPrim = makeSampleFrame(slot: .primary, timeSeconds: 1.000)
        let r1 = await synchronizer.enqueue(fPrim)
        #expect(r1 == nil) // Secondary not yet arrived

        // Secondary frame at t = 1.008s (8ms drift, well within 25ms tolerance)
        let fSec = makeSampleFrame(slot: .secondary, timeSeconds: 1.008)
        let r2 = await synchronizer.enqueue(fSec)

        #expect(r2 != nil)
        #expect(r2?.frames.count == 2)
        #expect(r2?.frames[.primary] != nil)
        #expect(r2?.frames[.secondary] != nil)
        #expect(r2?.maxDriftMs != nil && r2!.maxDriftMs < 10.0)
    }

    @Test("Triple camera mode matches 3 frames within tolerance")
    func tripleCameraModeMatches() async {
        let synchronizer = FrameSynchronizer(
            activeSlots: [.primary, .secondary, .tertiary],
            toleranceWindowSeconds: 0.030
        )

        let fPrim = makeSampleFrame(slot: .primary, timeSeconds: 2.000)
        let fSec  = makeSampleFrame(slot: .secondary, timeSeconds: 2.005)
        let fTert = makeSampleFrame(slot: .tertiary, timeSeconds: 2.010)

        _ = await synchronizer.enqueue(fPrim)
        _ = await synchronizer.enqueue(fSec)
        let r3 = await synchronizer.enqueue(fTert)

        #expect(r3 != nil)
        #expect(r3?.frames.count == 3)
        #expect(r3?.frames[.primary] != nil)
        #expect(r3?.frames[.secondary] != nil)
        #expect(r3?.frames[.tertiary] != nil)
    }

    @Test("Holding last frame prevents stall when secondary drops a single frame")
    func holdLastFrameOnDrop() async {
        let synchronizer = FrameSynchronizer(
            activeSlots: [.primary, .secondary],
            toleranceWindowSeconds: 0.020,
            holdLastFrameOnDrop: true
        )

        // Initial synced pair at t = 1.000
        _ = await synchronizer.enqueue(makeSampleFrame(slot: .primary, timeSeconds: 1.000))
        let initialPair = await synchronizer.enqueue(makeSampleFrame(slot: .secondary, timeSeconds: 1.000))
        #expect(initialPair != nil)

        // Next frame at t = 1.033 arrives for primary only (secondary dropped)
        let fPrim2 = makeSampleFrame(slot: .primary, timeSeconds: 1.033)
        let r2 = await synchronizer.enqueue(fPrim2)

        // Should pair fPrim2 with held secondary frame (which is only 33ms old <= 100ms threshold)
        #expect(r2 != nil)
        #expect(r2?.frames[.primary]?.timestamp.seconds == 1.033)
        #expect(r2?.frames[.secondary]?.timestamp.seconds == 1.000)
    }

    @Test("Flush clears all internal queues")
    func flushClearsQueues() async {
        let synchronizer = FrameSynchronizer(activeSlots: [.primary, .secondary])
        _ = await synchronizer.enqueue(makeSampleFrame(slot: .primary, timeSeconds: 1.0))
        await synchronizer.flush()

        // Enqueuing only secondary after flush should not match with the flushed primary
        let r = await synchronizer.enqueue(makeSampleFrame(slot: .secondary, timeSeconds: 1.0))
        #expect(r == nil)
    }
}
