// NDIAudioSender.swift
// NDI — Audio transmission worker for linear PCM audio sample buffers.
// Ingests audio from microphone captures and routes to the NDI backend.

import Foundation
import CoreMedia
import Domain
import os

// MARK: - Audio Queue Item

private struct AudioQueueItem: Sendable {
    let sampleBuffer: CMSampleBuffer
    let timecodeMicros: Int64?
}

// MARK: - NDI Audio Sender

/// Dedicated audio sender actor managing audio sample ingestion and backend transmission.
public actor NDIAudioSender {

    // MARK: - Configuration

    private let backend: NDIBackend
    private let senderID: String
    private let maxQueueDepth: Int

    // MARK: - Queuing & State

    private var queue: [AudioQueueItem] = []
    private var isProcessing: Bool = false
    private var isRunning: Bool = false

    // MARK: - Telemetry Counters

    public private(set) var totalSent: Int = 0
    public private(set) var totalDropped: Int = 0

    private let logger = Logger(subsystem: "com.tamandicam", category: "NDIAudioSender")

    // MARK: - Initialization

    public init(backend: NDIBackend, senderID: String, maxQueueDepth: Int = 5) {
        self.backend = backend
        self.senderID = senderID
        self.maxQueueDepth = max(maxQueueDepth, 1)
        self.isRunning = true
    }

    // MARK: - Public API

    /// Enqueues an audio sample buffer for transmission.
    public func enqueue(sampleBuffer: CMSampleBuffer, timecodeMicros: Int64? = nil) {
        guard isRunning else { return }

        if queue.count >= maxQueueDepth {
            queue.removeFirst()
            totalDropped += 1
            logger.debug("NDI audio queue full — dropped oldest audio packet")
        }

        let item = AudioQueueItem(sampleBuffer: sampleBuffer, timecodeMicros: timecodeMicros)
        queue.append(item)

        if !isProcessing {
            processNext()
        }
    }

    /// Stops audio processing and flushes pending buffers.
    public func stop() {
        isRunning = false
        queue.removeAll()
    }

    /// Resets drop and sent counters.
    public func resetCounters() {
        totalSent = 0
        totalDropped = 0
    }

    // MARK: - Processing Loop

    private func processNext() {
        guard isRunning, !queue.isEmpty else {
            isProcessing = false
            return
        }

        isProcessing = true
        let item = queue.removeFirst()

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.backend.sendAudioBuffer(
                    item.sampleBuffer,
                    timecodeMicros: item.timecodeMicros,
                    senderID: self.senderID
                )
                await self.recordSendSuccess()
            } catch {
                self.logger.error("Failed to send NDI audio buffer: \(error.localizedDescription)")
            }
            await self.processNext()
        }
    }

    private func recordSendSuccess() {
        totalSent += 1
    }
}
