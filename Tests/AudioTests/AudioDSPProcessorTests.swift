// AudioDSPProcessorTests.swift
// AudioTests — Unit tests for digital gain, muting, and level metering DSP functions.

import Testing
import Foundation
import AVFoundation
@testable import Audio
@testable import Domain

@Suite("AudioDSPProcessor Tests")
struct AudioDSPProcessorTests {

    private func makePCMBuffer(channelCount: UInt32, frameLength: UInt32, sampleRate: Double = 48000.0) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else { return nil }
        buffer.frameLength = frameLength
        return buffer
    }

    @Test("Silent buffer produces -160 dBFS floor and no clipping")
    func silentBuffer() throws {
        guard let buffer = makePCMBuffer(channelCount: 2, frameLength: 512) else {
            #expect(Bool(false), "Failed to allocate buffer")
            return
        }

        // Initialize with zeros
        for ch in 0..<2 {
            buffer.floatChannelData![ch].update(repeating: 0.0, count: 512)
        }

        let levels = AudioDSPProcessor.process(buffer: buffer, gain: 1.0, isMuted: false)
        #expect(levels.peakLevels[0] <= -160.0)
        #expect(levels.peakLevels[1] <= -160.0)
        #expect(levels.rmsLevels[0] <= -160.0)
        #expect(levels.isClipping == false)
    }

    @Test("Full scale 1.0 buffer produces 0.0 dBFS and triggers clipping")
    func fullScaleBuffer() throws {
        guard let buffer = makePCMBuffer(channelCount: 1, frameLength: 256) else {
            #expect(Bool(false), "Failed to allocate buffer")
            return
        }

        buffer.floatChannelData![0].update(repeating: 1.0, count: 256)

        let levels = AudioDSPProcessor.process(buffer: buffer, gain: 1.0, isMuted: false)
        #expect(abs(levels.peakLevels[0] - 0.0) < 0.01)
        #expect(abs(levels.rmsLevels[0] - 0.0) < 0.01)
        #expect(levels.isClipping == true)
    }

    @Test("Gain scaling multiplies sample values correctly")
    func gainScaling() throws {
        guard let buffer = makePCMBuffer(channelCount: 1, frameLength: 100) else {
            #expect(Bool(false), "Failed to allocate buffer")
            return
        }

        buffer.floatChannelData![0].update(repeating: 0.25, count: 100)

        // Gain = 2.0 should make samples 0.5 (-6.02 dBFS)
        let levels = AudioDSPProcessor.process(buffer: buffer, gain: 2.0, isMuted: false)
        #expect(buffer.floatChannelData![0][0] == 0.5)
        #expect(abs(levels.peakLevels[0] - (-6.02)) < 0.1)
        #expect(levels.isClipping == false)
    }

    @Test("Mute zeroes out buffer memory")
    func muteZeroesBuffer() throws {
        guard let buffer = makePCMBuffer(channelCount: 2, frameLength: 128) else {
            #expect(Bool(false), "Failed to allocate buffer")
            return
        }

        buffer.floatChannelData![0].update(repeating: 0.8, count: 128)
        buffer.floatChannelData![1].update(repeating: 0.8, count: 128)

        let levels = AudioDSPProcessor.process(buffer: buffer, gain: 1.0, isMuted: true)

        #expect(buffer.floatChannelData![0][0] == 0.0)
        #expect(buffer.floatChannelData![1][0] == 0.0)
        #expect(levels.peakLevels[0] <= -160.0)
        #expect(levels.peakLevels[1] <= -160.0)
        #expect(levels.isClipping == false)
    }

    @Test("computeLevels reads levels without mutating buffer")
    func computeLevelsReadonly() throws {
        guard let buffer = makePCMBuffer(channelCount: 1, frameLength: 64) else {
            #expect(Bool(false), "Failed to allocate buffer")
            return
        }

        buffer.floatChannelData![0].update(repeating: 0.5, count: 64)

        let levels = AudioDSPProcessor.computeLevels(buffer: buffer)
        #expect(buffer.floatChannelData![0][0] == 0.5)
        #expect(abs(levels.peakLevels[0] - (-6.02)) < 0.1)
    }
}
