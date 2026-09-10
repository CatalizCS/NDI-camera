// SignpostInstrumentation.swift
// Diagnostics — os_signpost instrumentation for pipeline performance profiling.

#if canImport(os)
import Foundation
import os

/// Provides `OSSignposter` instances for profiling pipeline stages in Instruments.
///
/// Usage:
/// ```swift
/// let state = SignpostInstrumentation.pipeline.beginInterval("frame-capture")
/// // ... do work ...
/// SignpostInstrumentation.pipeline.endInterval("frame-capture", state)
/// ```
public enum SignpostInstrumentation {

    // MARK: - Signposters

    /// Signposter for the camera/video capture pipeline.
    public static let pipeline = OSSignposter(
        subsystem: subsystem,
        category: "Pipeline"
    )

    /// Signposter for NDI encoding and transmission.
    public static let ndi = OSSignposter(
        subsystem: subsystem,
        category: "NDI"
    )

    /// Signposter for audio capture and processing.
    public static let audio = OSSignposter(
        subsystem: subsystem,
        category: "Audio"
    )

    /// Signposter for remote control server operations.
    public static let remote = OSSignposter(
        subsystem: subsystem,
        category: "Remote"
    )

    /// Signposter for session configuration changes.
    public static let session = OSSignposter(
        subsystem: subsystem,
        category: "Session"
    )

    // MARK: - Subsystem

    /// The shared subsystem identifier for all TamaNDI signposts.
    public static let subsystem = "com.tamandicam"

    // MARK: - Interval Names

    /// Standard interval names for pipeline signposts.
    public enum IntervalName {
        /// AVCaptureOutput callback duration.
        public static let frameCapture = "frame-capture"
        /// From callback to NDI enqueue.
        public static let frameToNDI = "frame-to-ndi"
        /// NDI send call duration.
        public static let ndiSend = "ndi-send"
        /// Audio callback duration.
        public static let audioCapture = "audio-capture"
        /// REST command processing.
        public static let remoteCommand = "remote-command"
        /// WebSocket state broadcast.
        public static let wsBroadcast = "ws-broadcast"
        /// AVCaptureSession configuration.
        public static let sessionConfigure = "session-configure"
    }
}
#endif
