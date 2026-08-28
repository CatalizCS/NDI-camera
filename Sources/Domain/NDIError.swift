// NDIError.swift
// Domain — Strongly-typed errors for the NDI streaming subsystem.

import Foundation

/// Errors produced by the NDI backend, senders, and streaming pipelines.
public enum NDIError: Error, Sendable, LocalizedError, Hashable {

    // MARK: - SDK & Backend Errors

    /// The physical NDI SDK framework is not installed or available on this system.
    case backendUnavailable(reason: String)

    /// Failed to initialize the NDI runtime library.
    case initializationFailed(reason: String)

    /// Failed to create an NDI sender instance.
    case senderCreationFailed(reason: String)

    /// The specified sender instance was not found or is no longer valid.
    case senderNotFound(id: String)

    // MARK: - Transmission Errors

    /// Failed to submit video frame payload to NDI runtime.
    case videoSendFailed(reason: String)

    /// Failed to submit audio sample payload to NDI runtime.
    case audioSendFailed(reason: String)

    /// Metadata transmission failed.
    case metadataSendFailed(reason: String)

    /// Network or output buffer backpressure caused critical queue overflow.
    case queueOverflow(droppedFrames: Int)

    // MARK: - Configuration & Lifecycle

    /// Invalid configuration parameters specified.
    case invalidConfiguration(reason: String)

    /// Operation attempted while broadcasting was not active.
    case notBroadcasting

    /// Operation attempted before the sender was initialized.
    case notInitialized

    // MARK: - Localized Descriptions

    public var errorDescription: String? {
        switch self {
        case .backendUnavailable(let reason):
            "NDI backend is unavailable: \(reason)"
        case .initializationFailed(let reason):
            "Failed to initialize NDI runtime: \(reason)"
        case .senderCreationFailed(let reason):
            "Failed to create NDI sender: \(reason)"
        case .senderNotFound(let id):
            "NDI sender '\(id)' was not found."
        case .videoSendFailed(let reason):
            "NDI video transmission failed: \(reason)"
        case .audioSendFailed(let reason):
            "NDI audio transmission failed: \(reason)"
        case .metadataSendFailed(let reason):
            "NDI metadata transmission failed: \(reason)"
        case .queueOverflow(let dropped):
            "NDI sender buffer queue overflowed (\(dropped) frames dropped due to network backpressure)."
        case .invalidConfiguration(let reason):
            "Invalid NDI configuration: \(reason)"
        case .notBroadcasting:
            "NDI sender is not currently broadcasting."
        case .notInitialized:
            "NDI sender has not been initialized."
        }
    }
}
