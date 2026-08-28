// NDISender.swift
// NDI — Actor-isolated NDI stream controller and coordinator.
// Conforms to NDISending protocol and abstracts the underlying NDIBackend.

import Foundation
import CoreMedia
import Domain
import os

// MARK: - NDI Sender

/// Production-grade actor managing an active NDI broadcast pipeline.
/// Coordinates video ingestion, audio ingestion, metadata, and telemetry over an abstract `NDIBackend`.
public actor NDISender: NDISending {

    // MARK: - Backend & Workers

    private let backend: NDIBackend
    private var videoSender: NDIVideoSender?
    private var audioSender: NDIAudioSender?
    private let statisticsCollector = NDIStatisticsCollector()

    // MARK: - State

    private var _configuration: NDIConfiguration
    private var _state: NDIStreamState = .idle
    private var activeSenderID: String?

    private let logger = Logger(subsystem: "com.tamandicam", category: "NDISender")

    // MARK: - Initialization

    public init(
        backend: NDIBackend = MockNDIBackend(),
        configuration: NDIConfiguration = NDIConfiguration()
    ) {
        self.backend = backend
        self._configuration = configuration
    }

    // MARK: - NDISending Lifecycle

    public func startBroadcasting(configuration: NDIConfiguration) async throws {
        logger.info("Starting NDI broadcast for source: '\(configuration.sourceName)'")
        _state = .initializing
        self._configuration = configuration

        do {
            // 1. Initialize backend if needed
            try await backend.initialize()

            // 2. Create active sender instance
            let senderID = try await backend.createSender(configuration: configuration)
            self.activeSenderID = senderID

            // 3. Initialize dedicated ingestion workers
            self.videoSender = NDIVideoSender(backend: backend, senderID: senderID)
            self.audioSender = NDIAudioSender(backend: backend, senderID: senderID)

            _state = .broadcasting
            logger.info("NDI sender active and broadcasting (ID: \(senderID))")
        } catch {
            _state = .error
            logger.error("Failed to start NDI broadcasting: \(error.localizedDescription)")
            throw error
        }
    }

    public func stopBroadcasting() async {
        logger.info("Stopping NDI broadcasting")
        if let senderID = activeSenderID {
            await videoSender?.stop()
            await audioSender?.stop()
            videoSender = nil
            audioSender = nil

            await backend.destroySender(id: senderID)
            self.activeSenderID = nil
        }

        await statisticsCollector.reset()
        _state = .idle
        logger.info("NDI broadcasting stopped")
    }

    public func updateConfiguration(_ configuration: NDIConfiguration) async throws {
        logger.info("Updating NDI configuration to source: '\(configuration.sourceName)'")
        self._configuration = configuration

        if _state == .broadcasting {
            // Re-create sender with updated configuration
            try await startBroadcasting(configuration: configuration)
        }
    }

    // MARK: - Frame Ingestion

    public func sendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer, timestamp: CMTime) async throws {
        guard _state == .broadcasting, let videoSender = self.videoSender else {
            throw NDIError.notBroadcasting
        }

        let timecodeMicros = Int64(timestamp.seconds * 1_000_000.0)
        await videoSender.enqueue(sampleBuffer: sampleBuffer, timecodeMicros: timecodeMicros)
        await statisticsCollector.recordVideoFrame()
    }

    public func sendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) async throws {
        guard _state == .broadcasting, let audioSender = self.audioSender else {
            throw NDIError.notBroadcasting
        }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timecodeMicros = Int64(pts.seconds * 1_000_000.0)
        await audioSender.enqueue(sampleBuffer: sampleBuffer, timecodeMicros: timecodeMicros)
        await statisticsCollector.recordAudioBuffer()
    }

    public func sendMetadata(_ metadata: NDIMetadata) async throws {
        guard _state == .broadcasting, let senderID = activeSenderID else {
            throw NDIError.notBroadcasting
        }

        try await backend.sendMetadata(metadata, senderID: senderID)
    }

    // MARK: - Telemetry & Status

    public func currentStats() async -> NDIStats {
        var stats = await statisticsCollector.snapshot()
        if let video = videoSender {
            let dropped = await video.totalDropped
            let sent = await video.totalSent
            stats = NDIStats(
                totalVideoFramesSent: sent,
                totalVideoFramesDropped: dropped,
                totalAudioFramesSent: stats.totalAudioFramesSent,
                currentBitrateMbps: stats.currentBitrateMbps,
                actualFPS: stats.actualFPS,
                tally: stats.tally,
                connectedReceiversCount: stats.connectedReceiversCount
            )
        }
        return stats
    }

    public func currentTally() async -> NDITally {
        guard let senderID = activeSenderID else { return .off }
        let tally = await backend.getTally(senderID: senderID)
        await statisticsCollector.updateTally(tally)
        return tally
    }

    public func currentState() -> NDIStreamState {
        _state
    }
}
