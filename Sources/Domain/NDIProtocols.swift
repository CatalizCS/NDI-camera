// NDIProtocols.swift
// Domain — Protocol boundaries for NDI backend abstraction and sender management.

import Foundation
import CoreMedia

// MARK: - NDI Stream State

/// Operational state of an active NDI broadcast pipeline.
public enum NDIStreamState: String, Sendable, Codable, Hashable {
    case idle
    case initializing
    case broadcasting
    case error
}

// MARK: - NDI Backend Protocol

/// Abstract interface for an underlying NDI runtime implementation.
/// Decouples the application, UI, and cameras from proprietary NDI C/C++ SDK dependencies.
public protocol NDIBackend: Sendable {

    /// Initializes the NDI library runtime.
    func initialize() async throws

    /// Destroys and cleans up the NDI library runtime.
    func destroy() async

    /// Creates an active NDI sender instance with the given configuration.
    /// Returns a unique string identifier representing the active sender instance.
    func createSender(configuration: NDIConfiguration) async throws -> String

    /// Destroys an active NDI sender instance by its identifier.
    func destroySender(id: String) async

    /// Submits a video sample buffer to the NDI sender output.
    func sendVideoBuffer(_ sampleBuffer: CMSampleBuffer, timecodeMicros: Int64?, senderID: String) async throws

    /// Submits an audio sample buffer (linear PCM) to the NDI sender output.
    func sendAudioBuffer(_ sampleBuffer: CMSampleBuffer, timecodeMicros: Int64?, senderID: String) async throws

    /// Sends connection metadata to subscribed NDI receivers.
    func sendMetadata(_ metadata: NDIMetadata, senderID: String) async throws

    /// Queries the current tally status (program/preview) from connected receivers.
    func getTally(senderID: String) async -> NDITally
}

// MARK: - NDI Sending Protocol

/// High-level interface controlling an NDI broadcast stream.
public protocol NDISending: Sendable {

    /// Starts broadcasting on the network with the specified configuration.
    func startBroadcasting(configuration: NDIConfiguration) async throws

    /// Stops broadcasting and disconnects active network senders.
    func stopBroadcasting() async

    /// Updates configuration parameters (such as source name or discovery groups) dynamically.
    func updateConfiguration(_ configuration: NDIConfiguration) async throws

    /// Enqueues a video frame for transmission without blocking the camera capture queue.
    func sendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer, timestamp: CMTime) async throws

    /// Enqueues an audio sample buffer for transmission.
    func sendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) async throws

    /// Broadcasts XML metadata to active NDI receivers.
    func sendMetadata(_ metadata: NDIMetadata) async throws

    /// Returns a snapshot of real-time transmission statistics.
    func currentStats() async -> NDIStats

    /// Returns the current tally state.
    func currentTally() async -> NDITally
}
