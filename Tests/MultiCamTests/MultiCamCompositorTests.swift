// MultiCamCompositorTests.swift
// MultiCamTests — Unit tests for MultiCamCompositor layout composition and CVPixelBuffer rendering.

import Testing
import Foundation
import CoreMedia
import CoreVideo
@testable import MultiCam
@testable import Domain

// MARK: - Helper Functions

private func makeColoredPixelBuffer(width: Int, height: Int) -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let attrs: [CFString: Any] = [
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        kCVPixelBufferMetalCompatibilityKey: true
    ]
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width, height,
        kCVPixelFormatType_32BGRA,
        attrs as CFDictionary,
        &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pb = pixelBuffer else {
        fatalError("Failed to create test pixel buffer")
    }
    return pb
}

private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer, pts: CMTime) -> CMSampleBuffer {
    var formatDesc: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
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
        imageBuffer: pixelBuffer,
        formatDescription: fd,
        sampleTiming: &timing,
        sampleBufferOut: &sampleBuffer
    )
    guard let sb = sampleBuffer else { fatalError() }
    return sb
}

// MARK: - MultiCam Compositor Tests

@Suite("MultiCamCompositor")
struct MultiCamCompositorTests {

    let compositor = MultiCamCompositor()

    @Test("Composes dual Picture-in-Picture into output pixel buffer")
    func compositePiP() throws {
        let pb1 = makeColoredPixelBuffer(width: 1920, height: 1080)
        let pb2 = makeColoredPixelBuffer(width: 1920, height: 1080)

        let pts = CMTime(value: 10, timescale: 30)
        let sb1 = makeSampleBuffer(from: pb1, pts: pts)
        let sb2 = makeSampleBuffer(from: pb2, pts: pts)

        let frame1 = MultiCamSampleFrame(slot: .primary, cameraID: "cam-wide", sampleBuffer: sb1, timestamp: pts)
        let frame2 = MultiCamSampleFrame(slot: .secondary, cameraID: "cam-ultra", sampleBuffer: sb2, timestamp: pts)

        let frameSet = SynchronizedFrameSet(
            frames: [.primary: frame1, .secondary: frame2],
            referenceTimestamp: pts,
            maxDriftMs: 0.0
        )

        let layout = CompositeLayout.pictureInPicture(position: .topRight, sizeFraction: 0.3)
        let targetRes = Resolution(width: 1280, height: 720)

        let outputPB = try compositor.composite(
            frameSet: frameSet,
            layout: layout,
            targetResolution: targetRes
        )

        #expect(CVPixelBufferGetWidth(outputPB) == 1280)
        #expect(CVPixelBufferGetHeight(outputPB) == 720)
    }

    @Test("Composes dual side-by-side split into output pixel buffer")
    func compositeSideBySide() throws {
        let pb1 = makeColoredPixelBuffer(width: 1280, height: 720)
        let pb2 = makeColoredPixelBuffer(width: 1280, height: 720)

        let pts = CMTime(value: 20, timescale: 30)
        let frame1 = MultiCamSampleFrame(slot: .primary, cameraID: "cam-1", sampleBuffer: makeSampleBuffer(from: pb1, pts: pts), timestamp: pts)
        let frame2 = MultiCamSampleFrame(slot: .secondary, cameraID: "cam-2", sampleBuffer: makeSampleBuffer(from: pb2, pts: pts), timestamp: pts)

        let frameSet = SynchronizedFrameSet(
            frames: [.primary: frame1, .secondary: frame2],
            referenceTimestamp: pts,
            maxDriftMs: 0.0
        )

        let layout = CompositeLayout.sideBySide(splitRatio: 0.5, isVertical: false)
        let targetRes = Resolution(width: 1920, height: 1080)

        let outputPB = try compositor.composite(
            frameSet: frameSet,
            layout: layout,
            targetResolution: targetRes
        )

        #expect(CVPixelBufferGetWidth(outputPB) == 1920)
        #expect(CVPixelBufferGetHeight(outputPB) == 1080)
    }

    @Test("Converts composited pixel buffer to CMSampleBuffer")
    func convertToSampleBuffer() throws {
        let pb = makeColoredPixelBuffer(width: 640, height: 360)
        let pts = CMTime(value: 30, timescale: 30)

        let sampleBuffer = try compositor.makeSampleBuffer(from: pb, timestamp: pts)
        #expect(CMSampleBufferGetPresentationTimeStamp(sampleBuffer) == pts)
        #expect(CMSampleBufferGetImageBuffer(sampleBuffer) != nil)
    }
}
