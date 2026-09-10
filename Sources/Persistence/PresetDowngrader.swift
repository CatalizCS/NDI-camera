// PresetDowngrader.swift
// Persistence — Pure function: Preset + Capabilities → adjusted Preset + warnings.

import Foundation
import Domain

/// Capability-aware preset downgrader.
/// Given a preset and current device capabilities, adjusts unsupported settings
/// and generates user-facing warnings.
public struct PresetDowngrader: Sendable {

    public init() {}

    /// Downgrade a preset's settings to match available capabilities.
    /// - Parameters:
    ///   - preset: The preset to downgrade
    ///   - capabilities: The current device capabilities
    /// - Returns: Adjusted preset and any warnings generated
    public func downgrade(_ preset: Preset, capabilities: DeviceCapabilities) -> PresetDowngradeResult {
        var adjustedSettings = preset.settings
        var warnings: [String] = []

        // Resolution downgrade
        if let resolution = adjustedSettings.resolution,
           !capabilities.supportedResolutions.contains(resolution) {
            if let fallback = capabilities.supportedResolutions.first {
                adjustedSettings = adjustedSettings.withResolution(fallback)
                warnings.append("Resolution downgraded from \(resolution) to \(fallback)")
            }
        }

        // FPS downgrade
        if let fps = adjustedSettings.fps, fps > capabilities.maxFPS {
            let fallbackFPS = capabilities.maxFPS
            adjustedSettings = adjustedSettings.withFPS(fallbackFPS)
            warnings.append("FPS downgraded from \(Int(fps)) to \(Int(fallbackFPS))")
        }

        // Camera mode downgrade
        if let mode = adjustedSettings.cameraMode {
            if (mode == "dualIndependent" || mode == "dualComposite" ||
                mode == "tripleIndependent" || mode == "tripleComposite") &&
                !capabilities.isMultiCamSupported {
                adjustedSettings = adjustedSettings.withCameraMode("single")
                warnings.append("Multi-camera mode '\(mode)' not supported — downgraded to single camera")
            }
        }

        // Stabilization downgrade
        if let stabilization = adjustedSettings.stabilization,
           !capabilities.supportedStabilizationModes.contains(stabilization) {
            let fallback = capabilities.supportedStabilizationModes.first ?? "off"
            adjustedSettings = adjustedSettings.withStabilization(fallback)
            warnings.append("Stabilization '\(stabilization)' not supported — using '\(fallback)'")
        }

        // Torch availability
        if adjustedSettings.torchEnabled == true && !capabilities.hasTorch {
            adjustedSettings = adjustedSettings.withTorchEnabled(false)
            warnings.append("Torch not available on this device")
        }

        let adjustedPreset = Preset(
            id: preset.id,
            name: preset.name,
            template: preset.template,
            isBuiltIn: preset.isBuiltIn,
            settings: adjustedSettings
        )

        return PresetDowngradeResult(adjustedPreset: adjustedPreset, warnings: warnings)
    }
}

// MARK: - Device Capabilities

/// Describes the capabilities of the current device for preset downgrading.
public struct DeviceCapabilities: Sendable {
    public let supportedResolutions: [String]
    public let maxFPS: Double
    public let isMultiCamSupported: Bool
    public let supportedStabilizationModes: [String]
    public let hasTorch: Bool

    public init(
        supportedResolutions: [String] = ["1920x1080", "1280x720"],
        maxFPS: Double = 60,
        isMultiCamSupported: Bool = false,
        supportedStabilizationModes: [String] = ["off", "standard"],
        hasTorch: Bool = true
    ) {
        self.supportedResolutions = supportedResolutions
        self.maxFPS = maxFPS
        self.isMultiCamSupported = isMultiCamSupported
        self.supportedStabilizationModes = supportedStabilizationModes
        self.hasTorch = hasTorch
    }
}

// MARK: - PresetSettings Mutation Helpers

extension PresetSettings {
    func withResolution(_ resolution: String?) -> PresetSettings {
        PresetSettings(resolution: resolution, fps: fps, cameraMode: cameraMode, stabilization: stabilization,
                       torchEnabled: torchEnabled, orientation: orientation, orientationLocked: orientationLocked,
                       audioMuted: audioMuted, audioGain: audioGain, ndiSourceName: ndiSourceName, ndiGroup: ndiGroup)
    }

    func withFPS(_ fps: Double?) -> PresetSettings {
        PresetSettings(resolution: resolution, fps: fps, cameraMode: cameraMode, stabilization: stabilization,
                       torchEnabled: torchEnabled, orientation: orientation, orientationLocked: orientationLocked,
                       audioMuted: audioMuted, audioGain: audioGain, ndiSourceName: ndiSourceName, ndiGroup: ndiGroup)
    }

    func withCameraMode(_ cameraMode: String?) -> PresetSettings {
        PresetSettings(resolution: resolution, fps: fps, cameraMode: cameraMode, stabilization: stabilization,
                       torchEnabled: torchEnabled, orientation: orientation, orientationLocked: orientationLocked,
                       audioMuted: audioMuted, audioGain: audioGain, ndiSourceName: ndiSourceName, ndiGroup: ndiGroup)
    }

    func withStabilization(_ stabilization: String?) -> PresetSettings {
        PresetSettings(resolution: resolution, fps: fps, cameraMode: cameraMode, stabilization: stabilization,
                       torchEnabled: torchEnabled, orientation: orientation, orientationLocked: orientationLocked,
                       audioMuted: audioMuted, audioGain: audioGain, ndiSourceName: ndiSourceName, ndiGroup: ndiGroup)
    }

    func withTorchEnabled(_ enabled: Bool?) -> PresetSettings {
        PresetSettings(resolution: resolution, fps: fps, cameraMode: cameraMode, stabilization: stabilization,
                       torchEnabled: enabled, orientation: orientation, orientationLocked: orientationLocked,
                       audioMuted: audioMuted, audioGain: audioGain, ndiSourceName: ndiSourceName, ndiGroup: ndiGroup)
    }
}
