// PresetManager.swift
// Persistence — Manages built-in and custom presets with capability-aware loading.

import Foundation
import Domain

/// Actor-isolated preset manager.
/// Provides 6 built-in presets, custom preset CRUD, capability-aware loading
/// with automatic downgrade, and JSON import/export with sanitization.
public actor PresetManager: PresetManaging {

    // MARK: - State

    private var customPresets: [String: Preset] = [:]
    private let settingsStore: SettingsStore
    private let downgrader: PresetDowngrader
    private let capabilities: DeviceCapabilities

    // MARK: - Init

    public init(settingsStore: SettingsStore, capabilities: DeviceCapabilities = DeviceCapabilities()) {
        self.settingsStore = settingsStore
        self.downgrader = PresetDowngrader()
        self.capabilities = capabilities
    }

    // MARK: - Built-in Presets

    /// The 6 built-in presets defined by the spec.
    public static let builtInPresets: [Preset] = [
        Preset(
            id: PresetTemplate.streaming1080p60.rawValue,
            name: PresetTemplate.streaming1080p60.displayName,
            template: .streaming1080p60,
            isBuiltIn: true,
            settings: PresetSettings(
                resolution: "1920x1080",
                fps: 60,
                cameraMode: "single",
                stabilization: "standard",
                torchEnabled: false,
                orientation: "auto",
                orientationLocked: false,
                audioMuted: false,
                ndiSourceName: "TamaNDI"
            )
        ),
        Preset(
            id: PresetTemplate.streaming4K30.rawValue,
            name: PresetTemplate.streaming4K30.displayName,
            template: .streaming4K30,
            isBuiltIn: true,
            settings: PresetSettings(
                resolution: "3840x2160",
                fps: 30,
                cameraMode: "single",
                stabilization: "standard",
                torchEnabled: false,
                orientation: "auto",
                orientationLocked: false,
                audioMuted: false,
                ndiSourceName: "TamaNDI"
            )
        ),
        Preset(
            id: PresetTemplate.lowBandwidth.rawValue,
            name: PresetTemplate.lowBandwidth.displayName,
            template: .lowBandwidth,
            isBuiltIn: true,
            settings: PresetSettings(
                resolution: "1280x720",
                fps: 30,
                cameraMode: "single",
                stabilization: "off",
                torchEnabled: false,
                orientation: "auto",
                orientationLocked: false,
                audioMuted: false,
                ndiSourceName: "TamaNDI"
            )
        ),
        Preset(
            id: PresetTemplate.highQuality.rawValue,
            name: PresetTemplate.highQuality.displayName,
            template: .highQuality,
            isBuiltIn: true,
            settings: PresetSettings(
                resolution: "3840x2160",
                fps: 60,
                cameraMode: "single",
                stabilization: "cinematic",
                torchEnabled: false,
                orientation: "auto",
                orientationLocked: false,
                audioMuted: false,
                ndiSourceName: "TamaNDI"
            )
        ),
        Preset(
            id: PresetTemplate.dualCamera.rawValue,
            name: PresetTemplate.dualCamera.displayName,
            template: .dualCamera,
            isBuiltIn: true,
            settings: PresetSettings(
                resolution: "1920x1080",
                fps: 30,
                cameraMode: "dualIndependent",
                stabilization: "standard",
                torchEnabled: false,
                orientation: "landscapeLeft",
                orientationLocked: true,
                audioMuted: false,
                ndiSourceName: "TamaNDI"
            )
        ),
        Preset(
            id: PresetTemplate.tripleComposite.rawValue,
            name: PresetTemplate.tripleComposite.displayName,
            template: .tripleComposite,
            isBuiltIn: true,
            settings: PresetSettings(
                resolution: "1920x1080",
                fps: 30,
                cameraMode: "tripleComposite",
                stabilization: "off",
                torchEnabled: false,
                orientation: "landscapeLeft",
                orientationLocked: true,
                audioMuted: false,
                ndiSourceName: "TamaNDI"
            )
        ),
    ]

    // MARK: - PresetManaging

    public func allPresets() -> [Preset] {
        Self.builtInPresets + Array(customPresets.values).sorted(by: { $0.name < $1.name })
    }

    public func loadPreset(id: String) throws -> PresetDowngradeResult {
        guard let preset = findPreset(id: id) else {
            throw PresetError.notFound(id)
        }
        let result = downgrader.downgrade(preset, capabilities: capabilities)
        return result
    }

    public func savePreset(_ preset: Preset) throws {
        guard !preset.isBuiltIn else {
            throw PresetError.cannotModifyBuiltIn
        }
        customPresets[preset.id] = preset
    }

    public func deletePreset(id: String) throws {
        guard let preset = customPresets[id] else {
            if Self.builtInPresets.contains(where: { $0.id == id }) {
                throw PresetError.cannotModifyBuiltIn
            }
            throw PresetError.notFound(id)
        }
        guard !preset.isBuiltIn else {
            throw PresetError.cannotModifyBuiltIn
        }
        customPresets.removeValue(forKey: id)
    }

    public func exportSettings() throws -> SettingsSnapshot {
        let currentSettings = PresetSettings() // Placeholder — in real app, read from SettingsStore
        let allCustom = Array(customPresets.values)
        return SettingsSnapshot(
            schemaVersion: 1,
            settings: currentSettings,
            presets: allCustom
        )
    }

    public func importSettings(_ snapshot: SettingsSnapshot) throws -> PresetDowngradeResult {
        // Import custom presets
        for preset in snapshot.presets where !preset.isBuiltIn {
            customPresets[preset.id] = preset
        }

        // Apply settings with downgrade
        let tempPreset = Preset(id: "import", name: "Imported", settings: snapshot.settings)
        let result = downgrader.downgrade(tempPreset, capabilities: capabilities)
        return result
    }

    // MARK: - Private

    private func findPreset(id: String) -> Preset? {
        if let builtin = Self.builtInPresets.first(where: { $0.id == id }) {
            return builtin
        }
        return customPresets[id]
    }
}

// MARK: - Preset Error

public enum PresetError: Error, Sendable {
    case notFound(String)
    case cannotModifyBuiltIn
    case invalidFormat(String)
}
