// MultiCamCaptureDelegate.swift
// MultiCam — Per-slot AVCaptureVideoDataOutput sample buffer delegate.
// Routes camera sample buffers to the synchronizer and independent streams on private serial queues.

import AVFoundation
import CoreMedia
import Domain
import Camera

// MARK: - MultiCam Capture Delegate

/// Thread-safe sample buffer delegate dedicated to a single MultiCamSlot.
/// Runs callbacks on the slot's private high-priority serial dispatch queue — never on the main thread.
final class MultiCamCaptureDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    /// The slot this delegate is attached to.
    let slot: MultiCamSlot

    /// Callback invoked when a video sample buffer is captured.
    var onFrame: (@Sendable (MultiCamSampleFrame) -> Void)?

    /// Callback invoked when a frame is dropped.
    var onDrop: (@Sendable (MultiCamSlot) -> Void)?

    /// Lock protecting mutable configuration properties.
    private let lock = NSLock()

    /// Underlying camera identifier.
    private var _cameraID: String = ""

    /// Camera unique ID attached to captured frames. Thread-safe.
    var cameraID: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _cameraID
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _cameraID = newValue
        }
    }

    // MARK: - Initialization

    init(slot: MultiCamSlot, cameraID: String = "") {
        self.slot = slot
        self._cameraID = cameraID
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frame = MultiCamSampleFrame(
            slot: slot,
            cameraID: cameraID,
            sampleBuffer: sampleBuffer,
            timestamp: timestamp
        )
        onFrame?(frame)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onDrop?(slot)
    }
}
