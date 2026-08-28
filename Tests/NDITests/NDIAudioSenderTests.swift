// NDIAudioSenderTests.swift
// NDITests — Unit tests for NDIAudioSender audio queueing and buffer submission.

import Testing
import Foundation
import CoreMedia
import CoreVideo
@testable import NDI
@testable import Domain

// MARK: - Test Helpers

private func makeAudioSampleBuffer(pts: CMTime) -> CMSampleBuffer {
    var blockBuffer: CMBlockBuffer?
    let dataSize = 1024
    let status = CMBlockBufferCreateWithMemoryBlock(
        allocator: kCFAllocatorDefault,
        memoryBlock: nil,
        blockLength: dataSize,
        blockAllocator: kCFAllocatorDefault,
        customBlockSource: nil,
        offsetToData: 0,
        dataLength: dataSize,
        flags: 0,
        blockBufferOut: &blockBuffer
    )
    guard status == kCFBlockBufferNoErr, let bb = blockBuffer else { fatalError() }

    var asbd = AudioStreamBasicDescription(
        mSampleRate: 48000.0,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 8,
        mFramesPerPacket: 1,
        mBytesPerFrame: 8,
        mChannelsPerFrame: 2,
        mBitsPerChannel: 32,
        mReserved: 0
    )

    var formatDesc: CMAudioFormatDescription?
    CMAudioFormatDescriptionCreate(
        allocator: kCFAllocatorDefault,
        asbd: &asbd,
        layoutSize: 0,
        layout: nil,
        magicCookieSize: 0,
        magicCookie: nil,
        extensions: nil,
        formatDescriptionOut: &formatDesc
    )
    guard let fd = formatDesc else { fatalError() }

    var timing = CMSampleTimingInfo(
        duration: CMTime(value: 128, timescale: 48000),
        presentationTimeStamp: pts,
        decodeTimeStamp: .invalid
    )

    var sampleBuffer: CMSampleBuffer?
    CMSampleBufferCreate(
        allocator: kCFAllocatorDefault,
        dataBuffer: bb,
        dataReady: true,
        makeDataReadyCallback: nil,
        refcon: nil,
        formatDescription: fd,
        sampleCount: 128,
        sampleTimingEntryCount: 1,
        sampleTimingArray: &timing,
        sampleSizeEntryCount: 0,
        sampleSizeArray: nil,
        sampleBufferOut: &sampleBuffer
    )
    guard let sb = sampleBuffer else { fatalError() }
    return sb
}

// MARK: - Audio Sender Tests

@Suite("NDIAudioSender")
struct NDIAudioSenderTests {

    @Test("Enqueues and sends audio sample buffers")
    func audioBufferSubmission() async throws {
        let backend = MockNDIBackend()
        try await backend.initialize()
        let senderID = try await backend.createSender(configuration: NDIConfiguration())

        let audioSender = NDIAudioSender(backend: backend, senderID: senderID)

        let pts = CMTime(value: 0, timescale: 48000)
        await audioSender.enqueue(sampleBuffer: makeAudioSampleBuffer(pts: pts), timecodeMicros: 0)

        try await Task.sleep(nanoseconds: 50_000_000)

        let sent = await audioSender.totalSent
        let dropped = await audioSender.totalDropped

        #expect(sent == 1)
        #expect(dropped == 0)
    }
}
