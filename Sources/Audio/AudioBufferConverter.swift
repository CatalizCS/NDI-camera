// AudioBufferConverter.swift
// Audio — Converter transforming AVAudioPCMBuffer into standard CMSampleBuffer for NDI and AVFoundation.

import Foundation
import CoreMedia
import CoreAudio
import AVFoundation
import Domain

// MARK: - Audio Buffer Converter

/// Converts AVAudioPCMBuffer instances into CMSampleBuffer structures with valid timing and format descriptions.
public final class AudioBufferConverter: Sendable {

    public init() {}

    /// Converts an AVAudioPCMBuffer to a CMSampleBuffer with the specified presentation timestamp.
    ///
    /// - Parameters:
    ///   - pcmBuffer: The source audio buffer.
    ///   - presentationTime: Presentation timestamp (`CMTime`).
    /// - Returns: A valid `CMSampleBuffer` containing the audio data.
    /// - Throws: `AudioError.conversionFailed` if format description or sample buffer creation fails.
    public func convertToCMSampleBuffer(
        pcmBuffer: AVAudioPCMBuffer,
        presentationTime: CMTime
    ) throws -> CMSampleBuffer {
        let frameCount = Int(pcmBuffer.frameLength)
        guard frameCount > 0 else {
            throw AudioError.conversionFailed(reason: "Empty PCM buffer (frameLength is 0)")
        }

        var asbd = pcmBuffer.format.streamDescription.pointee

        var formatDescription: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let formatDesc = formatDescription else {
            throw AudioError.conversionFailed(reason: "Failed to create CMAudioFormatDescription (OSStatus \(status))")
        }

        let audioBufferList = pcmBuffer.audioBufferList
        let bufferListPointer = audioBufferList.pointee
        let numBuffers = Int(bufferListPointer.mNumberBuffers)

        // Calculate total byte size across all channel buffers
        var totalBytes = 0
        for i in 0..<numBuffers {
            totalBytes += Int(audioBufferList.unsafePointer.pointee.mBuffers.mDataByteSize)
        }

        // Allocate memory block and copy data
        var blockBuffer: CMBlockBuffer?
        let blockStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: totalBytes,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: totalBytes,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard blockStatus == noErr, let block = blockBuffer else {
            throw AudioError.conversionFailed(reason: "Failed to allocate CMBlockBuffer (OSStatus \(blockStatus))")
        }

        // Copy channel data into block buffer
        var currentOffset = 0
        let buffers = UnsafeBufferPointer(
            start: &audioBufferList.unsafeMutablePointer.pointee.mBuffers,
            count: numBuffers
        )

        for buffer in buffers {
            if let data = buffer.mData {
                let size = Int(buffer.mDataByteSize)
                let copyStatus = CMBlockBufferReplaceDataBytes(
                    with: data,
                    blockBuffer: block,
                    offsetIntoDestination: currentOffset,
                    dataLength: size
                )
                guard copyStatus == noErr else {
                    throw AudioError.conversionFailed(reason: "Failed to copy audio data into CMBlockBuffer (OSStatus \(copyStatus))")
                }
                currentOffset += size
            }
        }

        // Create CMSampleBuffer
        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(asbd.mSampleRate)),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        let sampleBufferStatus = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: block,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleCount: CMItemCount(frameCount),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard sampleBufferStatus == noErr, let result = sampleBuffer else {
            throw AudioError.conversionFailed(reason: "Failed to create CMSampleBuffer (OSStatus \(sampleBufferStatus))")
        }

        return result
    }
}
