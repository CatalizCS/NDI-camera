// VideoCaptureDelegate.swift
// Camera — AVCaptureVideoDataOutput sample buffer delegate.
//
// Receives video frames on a dedicated serial queue and forwards them
// to registered consumers. No main-thread processing. No UIImage conversion.

import AVFoundation
import CoreMedia
import Domain

// MARK: - Video Frame

/// A captured video frame with its presentation timestamp and source camera ID.
public struct VideoFrame: Sendable {
    /// The raw pixel buffer. Held by reference — valid only while retained.
    public let sampleBuffer: CMSampleBuffer

    /// Presentation timestamp from the capture pipeline.
    public let timestamp: CMTime

    /// Identifier of the camera device that produced this frame.
    public let cameraID: String

    public init(sampleBuffer: CMSampleBuffer, timestamp: CMTime, cameraID: String) {
        self.sampleBuffer = sampleBuffer
        self.timestamp = timestamp
        self.cameraID = cameraID
    }
}

// MARK: - Video Capture Delegate

/// Delegate that receives video sample buffers from AVCaptureVideoDataOutput.
///
/// Thread safety:
/// - Callbacks occur on a dedicated serial queue (`videoOutputQueue`), never on the main thread.
/// - The delegate is `@unchecked Sendable` because all mutation is serialized on that queue,
///   except for `cameraID` which is protected by a lock (written by the actor, read by the callback queue).
/// - The `onFrame` callback must be `@Sendable` to safely cross the isolation boundary.
final class VideoCaptureDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    /// Callback invoked for each captured video frame.
    /// Called on the video output serial queue — never on main thread.
    var onFrame: (@Sendable (VideoFrame) -> Void)?

    /// Callback invoked when a frame is dropped due to late processing.
    var onFrameDropped: (@Sendable () -> Void)?

    /// Lock protecting `_cameraID` against concurrent read/write.
    private let lock = NSLock()

    /// Backing storage for `cameraID`.
    private var _cameraID: String = ""

    /// The camera device ID to attach to each frame.
    /// Thread-safe: protected by `lock`.
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

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frame = VideoFrame(
            sampleBuffer: sampleBuffer,
            timestamp: timestamp,
            cameraID: cameraID
        )
        onFrame?(frame)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrameDropped?()
    }
}

// MARK: - Audio Capture Delegate

/// Delegate that receives audio sample buffers from AVCaptureAudioDataOutput.
///
/// Thread safety: Same model as `VideoCaptureDelegate` — serialized on a dedicated queue.
final class AudioCaptureDelegate: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {

    /// Callback invoked for each captured audio sample buffer.
    var onAudioSample: (@Sendable (CMSampleBuffer) -> Void)?

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onAudioSample?(sampleBuffer)
    }
}
