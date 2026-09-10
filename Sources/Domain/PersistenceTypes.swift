// PersistenceTypes.swift
// Domain — Types for the persistence and preset subsystem.

import Foundation

// MARK: - Preset Template

/// Built-in preset templates provided by the app.
public enum PresetTemplate: String, Sendable, CaseIterable, Codable, Identifiable {
    case streaming1080p60 = "streaming_1080p60"
    case streaming4K30 = "streaming_4k30"
    case lowBandwidth = "low_bandwidth"
    case highQuality = "high_quality"
    case dualCamera = "dual_camera"
    case tripleComposite = "triple_composite"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .streaming1080p60: return "Streaming 1080p60"
        case .streaming4K30: return "Streaming 4K30"
        case .lowBandwidth: return "Low Bandwidth"
        case .highQuality: return "High Quality"
        case .dualCamera: return "Dual Camera"
        case .tripleComposite: return "Triple Composite"
        }
    }
}

// MARK: - Preset

/// A named configuration bundle with capability guards.
public struct Preset: Sendable, Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let template: PresetTemplate?
    public let isBuiltIn: Bool
    public let settings: PresetSettings

    public init(id: String, name: String, template: PresetTemplate? = nil, isBuiltIn: Bool = false, settings: PresetSettings) {
        self.id = id
        self.name = name
        self.template = template
        self.isBuiltIn = isBuiltIn
        self.settings = settings
    }
}

/// The actual settings values within a preset.
public struct PresetSettings: Sendable, Codable, Hashable {
    public let resolution: String?
    public let fps: Double?
    public let cameraMode: String?
    public let stabilization: String?
    public let torchEnabled: Bool?
    public let orientation: String?
    public let orientationLocked: Bool?
    public let audioMuted: Bool?
    public let audioGain: Float?
    public let ndiSourceName: String?
    public let ndiGroup: String?

    public init(
        resolution: String? = nil,
        fps: Double? = nil,
        cameraMode: String? = nil,
        stabilization: String? = nil,
        torchEnabled: Bool? = nil,
        orientation: String? = nil,
        orientationLocked: Bool? = nil,
        audioMuted: Bool? = nil,
        audioGain: Float? = nil,
        ndiSourceName: String? = nil,
        ndiGroup: String? = nil
    ) {
        self.resolution = resolution
        self.fps = fps
        self.cameraMode = cameraMode
        self.stabilization = stabilization
        self.torchEnabled = torchEnabled
        self.orientation = orientation
        self.orientationLocked = orientationLocked
        self.audioMuted = audioMuted
        self.audioGain = audioGain
        self.ndiSourceName = ndiSourceName
        self.ndiGroup = ndiGroup
    }
}

// MARK: - Preset Downgrade Result

/// Result of attempting to load a preset on hardware that may not fully support it.
public struct PresetDowngradeResult: Sendable {
    public let adjustedPreset: Preset
    public let warnings: [String]
    public let wasDowngraded: Bool

    public init(adjustedPreset: Preset, warnings: [String]) {
        self.adjustedPreset = adjustedPreset
        self.warnings = warnings
        self.wasDowngraded = !warnings.isEmpty
    }
}

// MARK: - Settings Snapshot

/// Complete app configuration for export/import (never includes secrets like tokens).
public struct SettingsSnapshot: Sendable, Codable {
    public let schemaVersion: Int
    public let exportedAt: Date
    public let settings: PresetSettings
    public let presets: [Preset]

    public init(schemaVersion: Int = 1, exportedAt: Date = Date(), settings: PresetSettings, presets: [Preset]) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.settings = settings
        self.presets = presets
    }
}
