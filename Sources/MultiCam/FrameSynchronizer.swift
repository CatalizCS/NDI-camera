// FrameSynchronizer.swift
// MultiCam — Multi-channel timestamp alignment and synchronization for multi-camera streams.
// Pairs asynchronous sample buffers across camera slots with bounded jitter tolerance.

import AVFoundation
import CoreMedia
import Domain
import os

// MARK: - MultiCam Sample Frame

/// A captured sample buffer tagged with its source MultiCamSlot and camera identifier.
public struct MultiCamSampleFrame: Sendable {
    public let slot: MultiCamSlot
    public let cameraID: String
    public let sampleBuffer: CMSampleBuffer
    public let timestamp: CMTime

    public init(slot: MultiCamSlot, cameraID: String, sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        self.slot = slot
        self.cameraID = cameraID
        self.sampleBuffer = sampleBuffer
        self.timestamp = timestamp
    }
}

// MARK: - Synchronized Frame Set

/// A group of time-aligned sample buffers from all active multi-cam slots ready for composite rendering.
public struct SynchronizedFrameSet: Sendable {
    /// Time-aligned frames keyed by their slot.
    public let frames: [MultiCamSlot: MultiCamSampleFrame]

    /// The reference presentation timestamp (typically from the primary slot).
    public let referenceTimestamp: CMTime

    /// Maximum time delta (drift) in milliseconds between any two paired frames in this set.
    public let maxDriftMs: Double

    public init(frames: [MultiCamSlot: MultiCamSampleFrame], referenceTimestamp: CMTime, maxDriftMs: Double) {
        self.frames = frames
        self.referenceTimestamp = referenceTimestamp
        self.maxDriftMs = maxDriftMs
    }
}

// MARK: - Frame Synchronizer

/// Actor that synchronizes multi-camera frame streams using a sliding presentation timestamp matching window.
public actor FrameSynchronizer {

    // MARK: - Configuration

    /// Currently expected active slots.
    private var activeSlots: Set<MultiCamSlot>

    /// Maximum allowable timestamp divergence between paired camera frames in seconds (default 25ms ~ 1 frame at 30fps).
    private var toleranceWindowSeconds: Double

    /// Maximum ring buffer capacity per slot.
    private let maxQueueCapacity: Int

    /// Whether to use the last valid frame if a slot experiences a temporary single-frame drop.
    private var holdLastFrameOnDrop: Bool

    /// Maximum age in seconds for a held frame before rejecting synthesis.
    private let maxHeldFrameAgeSeconds: Double = 0.10

    // MARK: - Queues & Cache

    /// Ring buffer per slot storing pending frames sorted by presentation timestamp.
    private var slotQueues: [MultiCamSlot: [MultiCamSampleFrame]] = [:]

    /// Last known successfully delivered frame per slot (for drop mitigation).
    private var lastKnownFrames: [MultiCamSlot: MultiCamSampleFrame] = [:]

    // MARK: - Diagnostics

    private var synchronizedSetsCount: Int = 0
    private var droppedFramesCount: Int = 0
    private var totalDriftMsAccumulator: Double = 0.0

    private let logger = Logger(subsystem: "com.tamandicam", category: "FrameSynchronizer")

    // MARK: - Initialization

    public init(
        activeSlots: Set<MultiCamSlot> = [.primary],
        toleranceWindowSeconds: Double = 0.025, // 25ms
        maxQueueCapacity: Int = 5,
        holdLastFrameOnDrop: Bool = true
    ) {
        self.activeSlots = activeSlots
        self.toleranceWindowSeconds = toleranceWindowSeconds
        self.maxQueueCapacity = maxQueueCapacity
        self.holdLastFrameOnDrop = holdLastFrameOnDrop

        for slot in activeSlots {
            slotQueues[slot] = []
        }
    }

    // MARK: - Public API

    /// Updates the set of active camera slots.
    public func setActiveSlots(_ slots: Set<MultiCamSlot>) {
        self.activeSlots = slots
        // Clean up queues for inactive slots
        for slot in MultiCamSlot.allCases where !slots.contains(slot) {
            slotQueues.removeValue(forKey: slot)
            lastKnownFrames.removeValue(forKey: slot)
        }
        for slot in slots where slotQueues[slot] == nil {
            slotQueues[slot] = []
        }
        logger.info("Active synchronizer slots updated: \(slots.map(\.rawValue).joined(separator: ", "))")
    }

    /// Sets the jitter tolerance window in seconds.
    public func setToleranceWindow(seconds: Double) {
        self.toleranceWindowSeconds = max(seconds, 0.005)
    }

    /// Enqueues a captured frame and attempts to produce a synchronized frame set.
    /// Returns a `SynchronizedFrameSet` if all active slots match within the tolerance window.
    public func enqueue(_ frame: MultiCamSampleFrame) -> SynchronizedFrameSet? {
        guard activeSlots.contains(frame.slot) else { return nil }

        // Fast path for single camera mode
        if activeSlots.count == 1 && activeSlots.contains(frame.slot) {
            synchronizedSetsCount += 1
            lastKnownFrames[frame.slot] = frame
            return SynchronizedFrameSet(
                frames: [frame.slot: frame],
                referenceTimestamp: frame.timestamp,
                maxDriftMs: 0.0
            )
        }

        // Insert into slot queue maintaining timestamp order
        var queue = slotQueues[frame.slot] ?? []
        insertSorted(frame: frame, into: &queue)

        // Trim queue if capacity exceeded
        if queue.count > maxQueueCapacity {
            queue.removeFirst(queue.count - maxQueueCapacity)
            droppedFramesCount += 1
        }
        slotQueues[frame.slot] = queue

        // Attempt alignment
        return matchSynchronizedFrames()
    }

    /// Flushes all pending queues and resets synchronization state.
    public func flush() {
        for slot in activeSlots {
            slotQueues[slot] = []
            lastKnownFrames[slot] = nil
        }
    }

    /// Returns synchronization telemetry diagnostics.
    public func diagnostics() -> (syncedSets: Int, droppedFrames: Int, avgDriftMs: Double) {
        let avgDrift = synchronizedSetsCount > 0 ? (totalDriftMsAccumulator / Double(synchronizedSetsCount)) : 0.0
        return (synchronizedSetsCount, droppedFramesCount, avgDrift)
    }

    // MARK: - Private Alignment Algorithm

    private func matchSynchronizedFrames() -> SynchronizedFrameSet? {
        // Ensure every active slot has at least one candidate frame or a valid held frame
        guard let primarySlot = activeSlots.contains(.primary) ? .primary : activeSlots.first else {
            return nil
        }

        guard let primaryQueue = slotQueues[primarySlot], !primaryQueue.isEmpty else {
            return nil
        }

        let refFrame = primaryQueue[0]
        let refTimeSeconds = refFrame.timestamp.seconds

        var matchedFrames: [MultiCamSlot: MultiCamSampleFrame] = [primarySlot: refFrame]
        var maxDeltaSeconds: Double = 0.0

        for slot in activeSlots where slot != primarySlot {
            guard var otherQueue = slotQueues[slot] else { return nil }

            // Find best matching frame in otherQueue
            var bestMatchIndex: Int?
            var smallestDiff: Double = .infinity

            for (index, candidate) in otherQueue.enumerated() {
                let diff = abs(candidate.timestamp.seconds - refTimeSeconds)
                if diff < smallestDiff {
                    smallestDiff = diff
                    bestMatchIndex = index
                }
            }

            if let bestIndex = bestMatchIndex, smallestDiff <= toleranceWindowSeconds {
                matchedFrames[slot] = otherQueue[bestIndex]
                maxDeltaSeconds = max(maxDeltaSeconds, smallestDiff)
            } else if holdLastFrameOnDrop, let lastGood = lastKnownFrames[slot] {
                let age = abs(refTimeSeconds - lastGood.timestamp.seconds)
                if age <= maxHeldFrameAgeSeconds {
                    matchedFrames[slot] = lastGood
                    maxDeltaSeconds = max(maxDeltaSeconds, age)
                } else {
                    // Difference too large and held frame too old — cannot synchronize yet
                    pruneOldFrames(for: slot, relativeTo: refTimeSeconds)
                    return nil
                }
            } else {
                pruneOldFrames(for: slot, relativeTo: refTimeSeconds)
                return nil
            }
        }

        // All active slots matched! Consume used frames from queues
        for (slot, matched) in matchedFrames {
            if var queue = slotQueues[slot] {
                queue.removeAll { $0.timestamp.seconds <= matched.timestamp.seconds }
                slotQueues[slot] = queue
            }
            lastKnownFrames[slot] = matched
        }

        let maxDriftMs = maxDeltaSeconds * 1000.0
        synchronizedSetsCount += 1
        totalDriftMsAccumulator += maxDriftMs

        return SynchronizedFrameSet(
            frames: matchedFrames,
            referenceTimestamp: refFrame.timestamp,
            maxDriftMs: maxDriftMs
        )
    }

    private func insertSorted(frame: MultiCamSampleFrame, into queue: inout [MultiCamSampleFrame]) {
        let frameSeconds = frame.timestamp.seconds
        if let idx = queue.firstIndex(where: { $0.timestamp.seconds > frameSeconds }) {
            queue.insert(frame, at: idx)
        } else {
            queue.append(frame)
        }
    }

    private func pruneOldFrames(for slot: MultiCamSlot, relativeTo refSeconds: Double) {
        guard var queue = slotQueues[slot] else { return }
        let initialCount = queue.count
        queue.removeAll { (refSeconds - $0.timestamp.seconds) > (toleranceWindowSeconds * 2.0) }
        let removed = initialCount - queue.count
        if removed > 0 {
            droppedFramesCount += removed
            slotQueues[slot] = queue
        }
    }
}
