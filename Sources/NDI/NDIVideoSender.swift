// NDIVideoSender.swift
// NDI — Video transmission worker with bounded queue depth and non-blocking backpressure.
// Ensures slow network transmission or NDI encoding never blocks the camera capture pipeline.

import Foundation
import CoreMedia
import Domain
import os

// MARK: - Video Queue Item

private struct VideoQueueItem: Sendable {
    let sampleBuffer: CMSampleBuffer
    let timecodeMicros: Int64?
}

// MARK: - NDI Video Sender

/// Dedicated video sender actor managing frame ingestion, backpressure dropping, and backend delivery.
public actor NDIVideoSender {

    // MARK: - Configuration

    private let backend: NDIBackend
    private let senderID: String
    private let maxQueueDepth: Int

    // MARK: - Queuing & State

    private var queue: [VideoQueueItem] = []
    private var isProcessing: Bool = false
    private var isRunning: Bool = false

    // MARK: - Telemetry Counters

    public private(set) var totalSent: Int = 0
    public private(set) var totalDropped: Int = 0

    private let logger = Logger(subsystem: "com.tamandicam", category: "NDIVideoSender")

    // MARK: - Initialization

    public init(backend: NDIBackend, senderID: String, maxQueueDepth: Int = 2) {
        self.backend = backend
        self.senderID = senderID
        self.maxQueueDepth = max(maxQueueDepth, 1)
        self.isRunning = true
    }

    // MARK: - Public API

    /// Enqueues a video frame for transmission.
    /// Non-blocking: if the queue is full, drops the oldest frame immediately.
    public func enqueue(sampleBuffer: CMSampleBuffer, timecodeMicros: Int64? = nil) {
        guard isRunning else { return }

        // Backpressure check: if queue depth reached, drop oldest pending frame
        if queue.count >= maxQueueDepth {
            queue.removeFirst()
            totalDropped += 1
            logger.debug("NDI video queue full — dropped oldest uncompressed frame (total dropped: \(self.totalDropped))")
        }

        let item = VideoQueueItem(sampleBuffer: sampleBuffer, timecodeMicros: timecodeMicros)
        queue.append(item)

        if !isProcessing {
            processNext()
        }
    }

    /// Stops video processing and clears pending queues.
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
                try await self.backend.sendVideoBuffer(
                    item.sampleBuffer,
                    timecodeMicros: item.timecodeMicros,
                    senderID: self.senderID
                )
                await self.recordSendSuccess()
            } catch {
                self.logger.error("Failed to send NDI video frame: \(error.localizedDescription)")
            }
            await self.processNext()
        }
    }

    private func recordSendSuccess() {
        totalSent += 1
    }
}
