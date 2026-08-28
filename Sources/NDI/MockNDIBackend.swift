// MockNDIBackend.swift
// NDI — In-memory Mock NDI Backend for development, testing, UI previews, and diagnostics.
// Operates without physical NDI C SDK binaries and performs no external networking.

import Foundation
import CoreMedia
import Domain
import os

// MARK: - Mock NDI Backend

/// Thread-safe in-memory NDI backend implementation conforming to `NDIBackend`.
/// Records video/audio frames, simulates remote tally feedback, and measures throughput for testing.
public actor MockNDIBackend: NDIBackend {

    // MARK: - State

    /// Whether the NDI runtime is currently initialized.
    public private(set) var isInitialized: Bool = false

    /// Active sender instances mapped by unique ID.
    private var senders: [String: NDIConfiguration] = [:]

    /// Simulated tally state per sender.
    private var tallies: [String: NDITally] = [:]

    /// Count of video frames sent per sender ID.
    private var videoFrameCounts: [String: Int] = [:]

    /// Count of audio buffers sent per sender ID.
    private var audioBufferCounts: [String: Int] = [:]

    /// Metadata history per sender ID.
    private var metadataHistory: [String: [NDIMetadata]] = [:]

    /// Last sent presentation timestamp per sender ID.
    private var lastTimestamps: [String: CMTime] = [:]

    /// Simulated connected receivers per sender.
    private var receiverCounts: [String: Int] = [:]

    // MARK: - Test Injections

    /// If true, next initialization will throw an error.
    public var shouldFailInitialization: Bool = false

    /// If true, next frame send will throw an error.
    public var shouldFailNextSend: Bool = false

    /// Simulated latency in seconds before completing send operations (for backpressure testing).
    public var simulatedSendLatency: Double = 0.0

    private var nextSenderIndex: Int = 1
    private let logger = Logger(subsystem: "com.tamandicam", category: "MockNDIBackend")

    // MARK: - Initialization

    public init() {}

    // MARK: - NDIBackend Lifecycle

    public func initialize() async throws {
        if shouldFailInitialization {
            throw NDIError.initializationFailed(reason: "Simulated initialization failure")
        }
        isInitialized = true
        logger.info("MockNDIBackend initialized successfully")
    }

    public func destroy() async {
        isInitialized = false
        senders.removeAll()
        tallies.removeAll()
        videoFrameCounts.removeAll()
        audioBufferCounts.removeAll()
        metadataHistory.removeAll()
        lastTimestamps.removeAll()
        receiverCounts.removeAll()
        logger.info("MockNDIBackend destroyed and reset")
    }

    public func createSender(configuration: NDIConfiguration) async throws -> String {
        guard isInitialized else {
            throw NDIError.notInitialized
        }

        let senderID = "mock_sender_\(nextSenderIndex)"
        nextSenderIndex += 1

        senders[senderID] = configuration
        tallies[senderID] = .off
        videoFrameCounts[senderID] = 0
        audioBufferCounts[senderID] = 0
        metadataHistory[senderID] = []
        receiverCounts[senderID] = 1 // default to 1 mock receiver

        logger.info("Created Mock NDI sender '\(configuration.sourceName)' with ID: \(senderID)")
        return senderID
    }

    public func destroySender(id: String) async {
        senders.removeValue(forKey: id)
        tallies.removeValue(forKey: id)
        videoFrameCounts.removeValue(forKey: id)
        audioBufferCounts.removeValue(forKey: id)
        metadataHistory.removeValue(forKey: id)
        lastTimestamps.removeValue(forKey: id)
        receiverCounts.removeValue(forKey: id)
        logger.info("Destroyed Mock NDI sender: \(id)")
    }

    // MARK: - Media Transmission

    public func sendVideoBuffer(_ sampleBuffer: CMSampleBuffer, timecodeMicros: Int64?, senderID: String) async throws {
        guard isInitialized else { throw NDIError.notInitialized }
        guard senders[senderID] != nil else { throw NDIError.senderNotFound(id: senderID) }

        if shouldFailNextSend {
            shouldFailNextSend = false
            throw NDIError.videoSendFailed(reason: "Simulated video transmission failure")
        }

        if simulatedSendLatency > 0 {
            try? await Task.sleep(nanoseconds: UInt64(simulatedSendLatency * 1_000_000_000))
        }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        lastTimestamps[senderID] = pts
        videoFrameCounts[senderID, default: 0] += 1
    }

    public func sendAudioBuffer(_ sampleBuffer: CMSampleBuffer, timecodeMicros: Int64?, senderID: String) async throws {
        guard isInitialized else { throw NDIError.notInitialized }
        guard senders[senderID] != nil else { throw NDIError.senderNotFound(id: senderID) }

        if shouldFailNextSend {
            shouldFailNextSend = false
            throw NDIError.audioSendFailed(reason: "Simulated audio transmission failure")
        }

        audioBufferCounts[senderID, default: 0] += 1
    }

    public func sendMetadata(_ metadata: NDIMetadata, senderID: String) async throws {
        guard isInitialized else { throw NDIError.notInitialized }
        guard senders[senderID] != nil else { throw NDIError.senderNotFound(id: senderID) }

        metadataHistory[senderID, default: []].append(metadata)
    }

    public func getTally(senderID: String) async -> NDITally {
        tallies[senderID] ?? .off
    }

    // MARK: - Test Inspection & Simulation Helpers

    /// Simulates a tally change from a remote switcher.
    public func simulateTally(senderID: String, tally: NDITally) {
        tallies[senderID] = tally
        logger.info("Simulated tally for \(senderID): Program=\(tally.inProgram), Preview=\(tally.inPreview)")
    }

    /// Sets the simulated number of connected receivers.
    public func setConnectedReceivers(senderID: String, count: Int) {
        receiverCounts[senderID] = count
    }

    /// Returns the total number of video frames sent for a sender.
    public func videoFramesSent(for senderID: String) -> Int {
        videoFrameCounts[senderID] ?? 0
    }

    /// Returns the total number of audio buffers sent for a sender.
    public func audioBuffersSent(for senderID: String) -> Int {
        audioBufferCounts[senderID] ?? 0
    }

    /// Returns the history of metadata messages sent.
    public func metadataSent(for senderID: String) -> [NDIMetadata] {
        metadataHistory[senderID] ?? []
    }

    /// Returns the last recorded presentation timestamp.
    public func lastTimestamp(for senderID: String) -> CMTime? {
        lastTimestamps[senderID]
    }
}
