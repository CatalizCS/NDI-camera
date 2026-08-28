// NDIVideoSenderTests.swift
// NDITests — Unit tests for NDIVideoSender queueing and backpressure frame dropping policy.

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
        32, 32,
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

// MARK: - Video Sender Tests

@Suite("NDIVideoSender")
struct NDIVideoSenderTests {

    @Test("Enqueues and sends video frames under normal throughput")
    func normalVideoTransmission() async throws {
        let backend = MockNDIBackend()
        try await backend.initialize()
        let senderID = try await backend.createSender(configuration: NDIConfiguration())

        let videoSender = NDIVideoSender(backend: backend, senderID: senderID, maxQueueDepth: 3)

        let pts = CMTime(value: 1, timescale: 30)
        await videoSender.enqueue(sampleBuffer: makeSampleBuffer(pts: pts), timecodeMicros: 100)

        // Allow async processing task to finish
        try await Task.sleep(nanoseconds: 50_000_000)

        let sent = await videoSender.totalSent
        let dropped = await videoSender.totalDropped

        #expect(sent == 1)
        #expect(dropped == 0)
    }

    @Test("Drops oldest uncompressed frame under simulated slow backend latency")
    func backpressureFrameDropping() async throws {
        let backend = MockNDIBackend()
        try await backend.initialize()
        // Simulate a very slow backend (100ms per frame)
        await MainActor.run {
            Task { await backend.setSimulatedSendLatency(0.10) }
        }
        let senderID = try await backend.createSender(configuration: NDIConfiguration())

        let videoSender = NDIVideoSender(backend: backend, senderID: senderID, maxQueueDepth: 2)

        // Ingest 5 frames rapidly into a queue with capacity 2
        for i in 0..<5 {
            let pts = CMTime(value: Int64(i), timescale: 30)
            await videoSender.enqueue(sampleBuffer: makeSampleBuffer(pts: pts), timecodeMicros: Int64(i * 1000))
        }

        let dropped = await videoSender.totalDropped
        #expect(dropped > 0) // Should have dropped frames due to backpressure
    }
}

extension MockNDIBackend {
    func setSimulatedSendLatency(_ latency: Double) {
        self.simulatedSendLatency = latency
    }
}
