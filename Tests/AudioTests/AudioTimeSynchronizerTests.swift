// AudioTimeSynchronizerTests.swift
// AudioTests — Unit tests for AudioTimeSynchronizer and AudioBufferConverter.

import Testing
import Foundation
import CoreMedia
import AVFoundation
@testable import Audio
@testable import Domain

@Suite("AudioTimeSynchronizer & BufferConverter Tests")
struct AudioTimeSynchronizerTests {

    @Test("AudioTimeSynchronizer converts host time to microseconds accurately")
    func hostTimeToMicros() {
        let synchronizer = AudioTimeSynchronizer()
        let hostNow = mach_absolute_time()
        let nanos = synchronizer.hostTimeToNanoseconds(hostNow)
        let micros = synchronizer.hostTimeToMicroseconds(hostNow)

        #expect(nanos > 0)
        #expect(micros > 0)
        #expect(micros == Int64(nanos / 1000))
    }

    @Test("synchronize with hostTime produces valid CMTime and microsecond timecode")
    func synchronizeHostTime() {
        let synchronizer = AudioTimeSynchronizer()
        let hostNow = mach_absolute_time()
        let audioTime = AVAudioTime(hostTime: hostNow, sampleRate: 48000.0, atRate: 48000.0)

        let (timestamp, timecode) = synchronizer.synchronize(audioTime: audioTime)
        #expect(timestamp.isValid)
        #expect(timestamp.timescale == 1_000_000_000)
        #expect(timecode > 0)
    }

    @Test("synchronize with sampleTime produces fractional CMTime")
    func synchronizeSampleTime() {
        let synchronizer = AudioTimeSynchronizer()
        let audioTime = AVAudioTime(sampleTime: 48000, atRate: 48000.0)

        let (timestamp, timecode) = synchronizer.synchronize(audioTime: audioTime)
        #expect(timestamp.isValid)
        #expect(timestamp.seconds == 1.0)
        #expect(timecode == 1_000_000) // 1 second in microseconds
    }

    @Test("currentTimestamp produces valid monotonically increasing time")
    func currentTimestamp() {
        let synchronizer = AudioTimeSynchronizer()
        let (ts1, tc1) = synchronizer.currentTimestamp()
        let (ts2, tc2) = synchronizer.currentTimestamp()

        #expect(ts1.isValid)
        #expect(ts2.isValid)
        #expect(tc2 >= tc1)
    }

    @Test("AudioBufferConverter creates CMSampleBuffer from AVAudioPCMBuffer")
    func convertBuffer() throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 2,
            interleaved: false
        ) else {
            #expect(Bool(false), "Failed to create AVAudioFormat")
            return
        }

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480) else {
            #expect(Bool(false), "Failed to allocate AVAudioPCMBuffer")
            return
        }
        pcmBuffer.frameLength = 480
        pcmBuffer.floatChannelData![0].update(repeating: 0.1, count: 480)
        pcmBuffer.floatChannelData![1].update(repeating: -0.1, count: 480)

        let converter = AudioBufferConverter()
        let time = CMTime(value: 0, timescale: 48000)
        let sampleBuffer = try converter.convertToCMSampleBuffer(pcmBuffer: pcmBuffer, presentationTime: time)

        #expect(CMSampleBufferGetNumSamples(sampleBuffer) == 480)
        #expect(CMSampleBufferGetPresentationTimeStamp(sampleBuffer) == time)
        #expect(CMSampleBufferIsValid(sampleBuffer))
    }

    @Test("AudioBufferConverter throws on empty buffer")
    func convertEmptyBufferThrows() {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 1,
            interleaved: false
        ) else { return }

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256) else { return }
        pcmBuffer.frameLength = 0 // empty

        let converter = AudioBufferConverter()
        let time = CMTime(value: 0, timescale: 48000)

        #expect(throws: AudioError.self) {
            try converter.convertToCMSampleBuffer(pcmBuffer: pcmBuffer, presentationTime: time)
        }
    }
}
