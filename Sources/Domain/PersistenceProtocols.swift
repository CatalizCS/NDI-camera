// PersistenceProtocols.swift
// Domain — Protocol boundaries for the persistence subsystem.

import Foundation

// MARK: - Preset Managing

/// CRUD operations for presets with capability-aware loading.
public protocol PresetManaging: Sendable {
    /// Lists all available presets (built-in + custom).
    func allPresets() async -> [Preset]

    /// Loads a preset by ID, returning downgrade info if settings were adjusted.
    func loadPreset(id: String) async throws -> PresetDowngradeResult

    /// Saves a custom preset.
    func savePreset(_ preset: Preset) async throws

    /// Deletes a custom preset. Built-in presets cannot be deleted.
    func deletePreset(id: String) async throws

    /// Exports settings as a JSON-safe snapshot (no secrets).
    func exportSettings() async throws -> SettingsSnapshot

    /// Imports settings from a snapshot, with capability downgrade.
    func importSettings(_ snapshot: SettingsSnapshot) async throws -> PresetDowngradeResult
}

// MARK: - Settings Storing

/// Reads, writes, and observes app settings via UserDefaults.
public protocol SettingsStoring: Sendable {
    /// Reads the current settings snapshot.
    func currentSettings() async -> PresetSettings

    /// Applies settings.
    func applySettings(_ settings: PresetSettings) async throws

    /// Resets all settings to defaults.
    func resetToDefaults() async
}
