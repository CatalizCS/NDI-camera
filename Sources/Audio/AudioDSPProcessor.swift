// AudioDSPProcessor.swift
// Audio — Real-time DSP processor for software gain scaling, mute silence injection, and dBFS metering.

import AVFoundation
import Domain

// MARK: - Audio DSP Processor

/// Real-time audio DSP processor executing digital gain, muting, and level metering.
public final class AudioDSPProcessor: @unchecked Sendable {

    // MARK: - Constants

    /// Minimum decibel floor (-160 dBFS).
    public static let minDbFloor: Float = -160.0

    /// Clipping threshold (~ -0.01 dBFS).
    public static let clippingThreshold: Float = 0.999

    // MARK: - Processing API

    /// Processes an AVAudioPCMBuffer in-place: applies gain and mute, then returns computed level meters.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer containing 32-bit floating point audio samples.
    ///   - gain: Linear gain multiplier (e.g. 1.0 = unity gain, 0.0 = silent, 2.0 = +6dB).
    ///   - isMuted: When true, all samples are zeroed out (silence injection).
    /// - Returns: A snapshot of peak and RMS decibel levels for each channel.
    @discardableResult
    public static func process(
        buffer: AVAudioPCMBuffer,
        gain: Float,
        isMuted: Bool
    ) -> AudioLevelsSnapshot {
        guard let floatChannelData = buffer.floatChannelData else {
            return AudioLevelsSnapshot.silence
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        guard channelCount > 0, frameLength > 0 else {
            return AudioLevelsSnapshot.silence
        }

        var peakLevels: [Float] = Array(repeating: minDbFloor, count: channelCount)
        var rmsLevels: [Float] = Array(repeating: minDbFloor, count: channelCount)
        var isClipping = false

        if isMuted {
            // Muted: Zero out all channel memory to preserve clock ticks without noise
            for ch in 0..<channelCount {
                let channelPointer = floatChannelData[ch]
                channelPointer.update(repeating: 0.0, count: frameLength)
            }
            return AudioLevelsSnapshot(
                peakLevels: peakLevels,
                rmsLevels: rmsLevels,
                isClipping: false,
                timestamp: Date()
            )
        }

        // Apply gain & compute meters
        for ch in 0..<channelCount {
            let channelPointer = floatChannelData[ch]
            var maxSample: Float = 0.0
            var sumSquare: Float = 0.0

            let applyGain = (gain != 1.0)

            for i in 0..<frameLength {
                var sample = channelPointer[i]

                if applyGain {
                    sample *= gain
                    channelPointer[i] = sample
                }

                let absSample = abs(sample)
                if absSample > maxSample {
                    maxSample = absSample
                }
                sumSquare += sample * sample
            }

            if maxSample >= clippingThreshold {
                isClipping = true
            }

            // Convert Peak to dBFS: 20 * log10(peak)
            if maxSample > 0.0 {
                let peakDb = 20.0 * log10(maxSample)
                peakLevels[ch] = max(peakDb, minDbFloor)
            } else {
                peakLevels[ch] = minDbFloor
            }

            // Convert RMS to dBFS: 20 * log10(sqrt(sumSquare / N))
            let meanSquare = sumSquare / Float(frameLength)
            if meanSquare > 0.0 {
                let rms = sqrt(meanSquare)
                let rmsDb = 20.0 * log10(rms)
                rmsLevels[ch] = max(rmsDb, minDbFloor)
            } else {
                rmsLevels[ch] = minDbFloor
            }
        }

        return AudioLevelsSnapshot(
            peakLevels: peakLevels,
            rmsLevels: rmsLevels,
            isClipping: isClipping,
            timestamp: Date()
        )
    }

    /// Computes levels on an existing buffer without modifying sample data.
    public static func computeLevels(buffer: AVAudioPCMBuffer) -> AudioLevelsSnapshot {
        guard let floatChannelData = buffer.floatChannelData else {
            return AudioLevelsSnapshot.silence
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        guard channelCount > 0, frameLength > 0 else {
            return AudioLevelsSnapshot.silence
        }

        var peakLevels: [Float] = Array(repeating: minDbFloor, count: channelCount)
        var rmsLevels: [Float] = Array(repeating: minDbFloor, count: channelCount)
        var isClipping = false

        for ch in 0..<channelCount {
            let channelPointer = floatChannelData[ch]
            var maxSample: Float = 0.0
            var sumSquare: Float = 0.0

            for i in 0..<frameLength {
                let sample = channelPointer[i]
                let absSample = abs(sample)
                if absSample > maxSample {
                    maxSample = absSample
                }
                sumSquare += sample * sample
            }

            if maxSample >= clippingThreshold {
                isClipping = true
            }

            if maxSample > 0.0 {
                peakLevels[ch] = max(20.0 * log10(maxSample), minDbFloor)
            } else {
                peakLevels[ch] = minDbFloor
            }

            let meanSquare = sumSquare / Float(frameLength)
            if meanSquare > 0.0 {
                let rms = sqrt(meanSquare)
                rmsLevels[ch] = max(20.0 * log10(rms), minDbFloor)
            } else {
                rmsLevels[ch] = minDbFloor
            }
        }

        return AudioLevelsSnapshot(
            peakLevels: peakLevels,
            rmsLevels: rmsLevels,
            isClipping: isClipping,
            timestamp: Date()
        )
    }
}
