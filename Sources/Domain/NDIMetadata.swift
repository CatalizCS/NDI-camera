// NDIMetadata.swift
// Domain — NDI metadata, connection tally state, and remote signaling models.

import Foundation

// MARK: - NDI Tally

/// Connection tally status signaled by downstream NDI receivers (e.g. TriCaster, vMix, OBS).
public struct NDITally: Sendable, Hashable, Codable {

    /// True if this source is actively on program (on-air / red tally).
    public let inProgram: Bool

    /// True if this source is selected on preview (cue / green tally).
    public let inPreview: Bool

    public init(inProgram: Bool = false, inPreview: Bool = false) {
        self.inProgram = inProgram
        self.inPreview = inPreview
    }

    /// No active tally (off-air).
    public static let off = NDITally(inProgram: false, inPreview: false)

    /// Program on-air tally.
    public static let program = NDITally(inProgram: true, inPreview: false)

    /// Preview cue tally.
    public static let preview = NDITally(inProgram: false, inPreview: true)
}

// MARK: - NDI Metadata

/// XML-formatted metadata payload exchanged with NDI receivers.
public struct NDIMetadata: Sendable, Hashable, Codable {

    /// The raw XML metadata string.
    public let payload: String

    /// Optional presentation timestamp in microseconds, if synchronized.
    public let timecodeMicros: Int64?

    public init(payload: String, timecodeMicros: Int64? = nil) {
        self.payload = payload
        self.timecodeMicros = timecodeMicros
    }
}
