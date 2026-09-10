// SettingsStore.swift
// Persistence — UserDefaults-backed settings storage with type-safe keys.

import Foundation
import Domain

/// Actor-isolated settings store backed by UserDefaults.
/// Provides type-safe reading and writing of app settings.
public actor SettingsStore: SettingsStoring {

    // MARK: - Keys

    private enum Key: String {
        case resolution
        case fps
        case cameraMode
        case stabilization
        case torchEnabled
        case orientation
        case orientationLocked
        case audioMuted
        case audioGain
        case ndiSourceName
        case ndiGroup
    }

    // MARK: - State

    private let defaults: UserDefaults
    private let suiteName: String?

    // MARK: - Init

    /// Creates a settings store.
    /// - Parameter suiteName: Optional UserDefaults suite name. Uses standard defaults if nil.
    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
        if let suiteName {
            self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        } else {
            self.defaults = .standard
        }
    }

    // MARK: - SettingsStoring

    public func currentSettings() -> PresetSettings {
        PresetSettings(
            resolution: defaults.string(forKey: Key.resolution.rawValue),
            fps: defaults.object(forKey: Key.fps.rawValue) as? Double,
            cameraMode: defaults.string(forKey: Key.cameraMode.rawValue),
            stabilization: defaults.string(forKey: Key.stabilization.rawValue),
            torchEnabled: defaults.object(forKey: Key.torchEnabled.rawValue) as? Bool,
            orientation: defaults.string(forKey: Key.orientation.rawValue),
            orientationLocked: defaults.object(forKey: Key.orientationLocked.rawValue) as? Bool,
            audioMuted: defaults.object(forKey: Key.audioMuted.rawValue) as? Bool,
            audioGain: defaults.object(forKey: Key.audioGain.rawValue) as? Float,
            ndiSourceName: defaults.string(forKey: Key.ndiSourceName.rawValue),
            ndiGroup: defaults.string(forKey: Key.ndiGroup.rawValue)
        )
    }

    public func applySettings(_ settings: PresetSettings) throws {
        setOptional(settings.resolution, forKey: .resolution)
        setOptional(settings.fps, forKey: .fps)
        setOptional(settings.cameraMode, forKey: .cameraMode)
        setOptional(settings.stabilization, forKey: .stabilization)
        setOptional(settings.torchEnabled, forKey: .torchEnabled)
        setOptional(settings.orientation, forKey: .orientation)
        setOptional(settings.orientationLocked, forKey: .orientationLocked)
        setOptional(settings.audioMuted, forKey: .audioMuted)
        setOptional(settings.audioGain, forKey: .audioGain)
        setOptional(settings.ndiSourceName, forKey: .ndiSourceName)
        setOptional(settings.ndiGroup, forKey: .ndiGroup)
    }

    public func resetToDefaults() {
        for key in Key.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    // MARK: - Private

    private func setOptional(_ value: Any?, forKey key: Key) {
        if let value {
            defaults.set(value, forKey: key.rawValue)
        }
    }
}

// MARK: - Key CaseIterable

extension SettingsStore.Key: CaseIterable {}
