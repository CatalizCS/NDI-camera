// AudioError.swift
// Domain — Strongly-typed localized error definitions for the audio subsystem.

import Foundation

public enum AudioError: LocalizedError, Sendable, Hashable {
    case permissionDenied
    case deviceNotFound(deviceID: String)
    case sessionActivationFailed(reason: String)
    case categoryConfigurationFailed(reason: String)
    case portSelectionFailed(reason: String)
    case dataSourceSelectionFailed(reason: String)
    case unsupportedSampleRate(requested: Double)
    case unsupportedChannelCount(requested: Int)
    case gainNotSupported
    case engineStartFailed(reason: String)
    case conversionFailed(reason: String)
    case notRunning
    case alreadyRunning

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access was denied by the user."
        case .deviceNotFound(let deviceID):
            return "The requested audio input device was not found (ID: \(deviceID))."
        case .sessionActivationFailed(let reason):
            return "Failed to activate AVAudioSession: \(reason)"
        case .categoryConfigurationFailed(let reason):
            return "Failed to configure AVAudioSession category: \(reason)"
        case .portSelectionFailed(let reason):
            return "Failed to select audio input port: \(reason)"
        case .dataSourceSelectionFailed(let reason):
            return "Failed to select microphone data source / polar pattern: \(reason)"
        case .unsupportedSampleRate(let requested):
            return "The requested sample rate (\(requested) Hz) is not supported by the hardware."
        case .unsupportedChannelCount(let requested):
            return "The requested channel count (\(requested)) is not supported by the hardware."
        case .gainNotSupported:
            return "Hardware input gain is not supported on this audio device."
        case .engineStartFailed(let reason):
            return "Failed to start AVAudioEngine: \(reason)"
        case .conversionFailed(let reason):
            return "Audio buffer conversion failed: \(reason)"
        case .notRunning:
            return "The audio capture engine is not running."
        case .alreadyRunning:
            return "The audio capture engine is already running."
        }
    }
}
