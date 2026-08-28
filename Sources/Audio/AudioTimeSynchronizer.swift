// AudioTimeSynchronizer.swift
// Audio — Accurate time synchronization converting host/audio time to CMTime and microsecond timecodes.

import Foundation
import CoreMedia
import AVFoundation

// MARK: - Audio Time Synchronizer

/// Converts audio timestamps and sample counts into presentation timestamps (`CMTime`)
/// and synchronized microsecond timecodes aligned with the system capture clock.
public final class AudioTimeSynchronizer: Sendable {

    // MARK: - Timebase Info

    private let timebaseNumerator: UInt32
    private let timebaseDenominator: UInt32

    // MARK: - Initialization

    public init() {
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        self.timebaseNumerator = max(info.numer, 1)
        self.timebaseDenominator = max(info.denom, 1)
    }

    // MARK: - Public Time Conversion

    /// Converts a mach absolute host time unit into nanoseconds.
    public func hostTimeToNanoseconds(_ hostTime: UInt64) -> UInt64 {
        return (hostTime * UInt64(timebaseNumerator)) / UInt64(timebaseDenominator)
    }

    /// Converts a mach absolute host time unit into microseconds.
    public func hostTimeToMicroseconds(_ hostTime: UInt64) -> Int64 {
        let nanos = hostTimeToNanoseconds(hostTime)
        return Int64(nanos / 1000)
    }

    /// Converts an AVAudioTime to CMTime presentation timestamp and microsecond timecode.
    ///
    /// - Parameters:
    ///   - audioTime: Timestamp provided by the audio hardware / tap.
    ///   - fallbackSampleRate: Fallback sample rate in Hz if audioTime.sampleRate is invalid.
    /// - Returns: A tuple containing the synchronized `CMTime` and `timecodeMicros`.
    public func synchronize(audioTime: AVAudioTime, fallbackSampleRate: Double = 48000.0) -> (timestamp: CMTime, timecodeMicros: Int64) {
        let sampleRate = audioTime.sampleRate > 0 ? audioTime.sampleRate : fallbackSampleRate

        let timecode: Int64
        let cmTimestamp: CMTime

        if audioTime.isHostTimeValid && audioTime.hostTime > 0 {
            timecode = hostTimeToMicroseconds(audioTime.hostTime)
            let nanos = hostTimeToNanoseconds(audioTime.hostTime)
            cmTimestamp = CMTime(value: CMTimeValue(nanos), timescale: 1_000_000_000)
        } else if audioTime.isSampleTimeValid {
            let sampleTime = audioTime.sampleTime
            cmTimestamp = CMTime(value: CMTimeValue(sampleTime), timescale: CMTimeScale(sampleRate))
            let micros = (Double(sampleTime) / sampleRate) * 1_000_000.0
            timecode = Int64(micros)
        } else {
            let nowHost = mach_absolute_time()
            timecode = hostTimeToMicroseconds(nowHost)
            let nanos = hostTimeToNanoseconds(nowHost)
            cmTimestamp = CMTime(value: CMTimeValue(nanos), timescale: 1_000_000_000)
        }

        return (cmTimestamp, timecode)
    }

    /// Generates a current host-time synchronized timestamp and timecode.
    public func currentTimestamp() -> (timestamp: CMTime, timecodeMicros: Int64) {
        let nowHost = mach_absolute_time()
        let nanos = hostTimeToNanoseconds(nowHost)
        let timecode = Int64(nanos / 1000)
        let cmTimestamp = CMTime(value: CMTimeValue(nanos), timescale: 1_000_000_000)
        return (cmTimestamp, timecode)
    }
}
