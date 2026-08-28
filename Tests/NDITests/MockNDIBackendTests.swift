// MockNDIBackendTests.swift
// NDITests — Unit tests for MockNDIBackend lifecycle, video/audio submission, and tally simulation.

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

// MARK: - Mock NDI Backend Tests

@Suite("MockNDIBackend")
struct MockNDIBackendTests {

    @Test("Lifecycle: initialization, sender creation, and destruction")
    func backendLifecycle() async throws {
        let backend = MockNDIBackend()
        #expect(await !backend.isInitialized)

        try await backend.initialize()
        #expect(await backend.isInitialized)

        let config = NDIConfiguration(sourceName: "TestCam")
        let senderID = try await backend.createSender(configuration: config)
        #expect(!senderID.isEmpty)

        await backend.destroySender(id: senderID)
        await backend.destroy()
        #expect(await !backend.isInitialized)
    }

    @Test("Video frame transmission records frame count and presentation timestamp")
    func videoFrameSubmission() async throws {
        let backend = MockNDIBackend()
        try await backend.initialize()

        let senderID = try await backend.createSender(configuration: NDIConfiguration())
        let pts = CMTime(value: 100, timescale: 30)
        let sampleBuffer = makeSampleBuffer(pts: pts)

        try await backend.sendVideoBuffer(sampleBuffer, timecodeMicros: 1000, senderID: senderID)

        let count = await backend.videoFramesSent(for: senderID)
        let recordedPts = await backend.lastTimestamp(for: senderID)

        #expect(count == 1)
        #expect(recordedPts == pts)
    }

    @Test("Tally simulation updates program and preview states")
    func tallySimulation() async throws {
        let backend = MockNDIBackend()
        try await backend.initialize()

        let senderID = try await backend.createSender(configuration: NDIConfiguration())
        let initialTally = await backend.getTally(senderID: senderID)
        #expect(!initialTally.inProgram && !initialTally.inPreview)

        await backend.simulateTally(senderID: senderID, tally: .program)
        let programTally = await backend.getTally(senderID: senderID)
        #expect(programTally.inProgram && !programTally.inPreview)

        await backend.simulateTally(senderID: senderID, tally: .preview)
        let previewTally = await backend.getTally(senderID: senderID)
        #expect(!previewTally.inProgram && previewTally.inPreview)
    }

    @Test("Metadata transmission records history")
    func metadataSubmission() async throws {
        let backend = MockNDIBackend()
        try await backend.initialize()

        let senderID = try await backend.createSender(configuration: NDIConfiguration())
        let meta = NDIMetadata(payload: "<lens fov=\"65.0\"/>")

        try await backend.sendMetadata(meta, senderID: senderID)
        let history = await backend.metadataSent(for: senderID)

        #expect(history.count == 1)
        #expect(history.first?.payload.contains("65.0") == true)
    }

    @Test("Rejects operations before initialization")
    func rejectsUninitialized() async {
        let backend = MockNDIBackend()
        #expect(throws: NDIError.self) {
            try await backend.createSender(configuration: NDIConfiguration())
        }
    }
}
