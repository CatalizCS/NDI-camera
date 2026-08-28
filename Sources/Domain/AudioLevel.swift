// AudioLevel.swift
// Domain — Value types for audio level metering (peak, RMS in dBFS).

import Foundation

// MARK: - Audio Levels Snapshot

/// Instantaneous audio level measurement in decibels relative to full scale (dBFS).
public struct AudioLevelsSnapshot: Sendable, Hashable, Codable {
    /// Peak decibel levels per channel (range: -160.0 dBFS to 0.0 dBFS).
    public let peakLevels: [Float]
    /// Root Mean Square (average) decibel levels per channel.
    public let rmsLevels: [Float]
    /// Whether any channel is currently clipping (peak >= -0.1 dBFS).
    public let isClipping: Bool
    /// Timestamp when this measurement was calculated.
    public let timestamp: Date

    public init(
        peakLevels: [Float] = [-160.0, -160.0],
        rmsLevels: [Float] = [-160.0, -160.0],
        isClipping: Bool = false,
        timestamp: Date = Date()
    ) {
        self.peakLevels = peakLevels
        self.rmsLevels = rmsLevels
        self.isClipping = isClipping
        self.timestamp = timestamp
    }

    /// Silence baseline constant (-160 dBFS).
    public static let silence = AudioLevelsSnapshot(
        peakLevels: [-160.0, -160.0],
        rmsLevels: [-160.0, -160.0],
        isClipping: false,
        timestamp: Date()
    )
}
