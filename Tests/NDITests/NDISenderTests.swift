// NDISenderTests.swift
// NDITests — Unit tests for NDISender actor lifecycle, broadcasting, and telemetry.

import Testing
import Foundation
import CoreMedia
import CoreVideo
@testable import NDI
@testable import Domain

// MARK: - Test Helpers

private func makeSampleBuffer(pts: CMTime) -> CMSampleBuffer {
    var pixelBuffer: CVPixelBuffer?
    let attrs: [CFString: Any] = [
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
    ]
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        64, 64,
        kCVPixelFormatType_32BGRA,
        attrs as CFDictionary,
        &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pb = pixelBuffer else { fatalError() }

    var formatDesc: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pb,
        formatDescriptionOut: &formatDesc
    )
    guard let fd = formatDesc else { fatalError() }

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
    guard let sb = sampleBuffer else { fatalError() }
    return sb
}

// MARK: - NDISender Tests

@Suite("NDISender")
struct NDISenderTests {

    @Test("Starts and stops broadcasting successfully with MockNDIBackend")
    func startStopBroadcasting() async throws {
        let backend = MockNDIBackend()
        let sender = NDISender(backend: backend)

        let initial = await sender.currentState()
        #expect(initial == .idle)

        let config = NDIConfiguration(sourceName: "LiveCam-1")
        try await sender.startBroadcasting(configuration: config)

        let activeState = await sender.currentState()
        #expect(activeState == .broadcasting)

        await sender.stopBroadcasting()
        let finalState = await sender.currentState()
        #expect(finalState == .idle)
    }

    @Test("Transmits video sample buffers and reflects in statistics")
    func transmitVideoFrames() async throws {
        let backend = MockNDIBackend()
        let sender = NDISender(backend: backend)

        try await sender.startBroadcasting(configuration: NDIConfiguration())

        let pts = CMTime(value: 10, timescale: 30)
        let sampleBuffer = makeSampleBuffer(pts: pts)

        try await sender.sendVideoSampleBuffer(sampleBuffer, timestamp: pts)

        try await Task.sleep(nanoseconds: 50_000_000)

        let stats = await sender.currentStats()
        #expect(stats.totalVideoFramesSent == 1)
        #expect(stats.totalVideoFramesDropped == 0)

        await sender.stopBroadcasting()
    }

    @Test("Rejects video transmission when not broadcasting")
    func rejectTransmissionWhenIdle() async {
        let sender = NDISender()
        let pts = CMTime(value: 1, timescale: 30)
        let sampleBuffer = makeSampleBuffer(pts: pts)

        #expect(throws: NDIError.self) {
            try await sender.sendVideoSampleBuffer(sampleBuffer, timestamp: pts)
        }
    }

    @Test("Queries tally feedback from backend")
    func tallyQuery() async throws {
        let backend = MockNDIBackend()
        let sender = NDISender(backend: backend)

        try await sender.startBroadcasting(configuration: NDIConfiguration())
        let tally = await sender.currentTally()
        #expect(!tally.inProgram && !tally.inPreview)

        await sender.stopBroadcasting()
    }
}
