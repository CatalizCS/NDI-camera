// PresetDowngraderTests.swift
// Tests for capability-aware preset downgrading.

import Testing
import Foundation
@testable import Persistence
@testable import Domain

@Suite("Preset Downgrader Tests")
struct PresetDowngraderTests {

    private let downgrader = PresetDowngrader()

    @Test("No downgrade needed — all capabilities match")
    func testNoDowngrade() {
        let settings = PresetSettings(resolution: "1920x1080", fps: 60, stabilization: "standard")
        let preset = Preset(id: "test", name: "Test", settings: settings)
        let caps = DeviceCapabilities(
            supportedResolutions: ["1920x1080", "3840x2160"],
            maxFPS: 60,
            supportedStabilizationModes: ["off", "standard"]
        )

        let result = downgrader.downgrade(preset, capabilities: caps)
        #expect(result.wasDowngraded == false)
        #expect(result.warnings.isEmpty)
    }

    @Test("Resolution downgrade")
    func testResolutionDowngrade() {
        let settings = PresetSettings(resolution: "3840x2160")
        let preset = Preset(id: "test", name: "Test", settings: settings)
        let caps = DeviceCapabilities(
            supportedResolutions: ["1920x1080", "1280x720"],
            maxFPS: 60
        )

        let result = downgrader.downgrade(preset, capabilities: caps)
        #expect(result.wasDowngraded == true)
        #expect(result.adjustedPreset.settings.resolution == "1920x1080")
        #expect(result.warnings.count == 1)
        #expect(result.warnings.first?.contains("Resolution downgraded") == true)
    }

    @Test("FPS downgrade")
    func testFPSDowngrade() {
        let settings = PresetSettings(fps: 120)
        let preset = Preset(id: "test", name: "Test", settings: settings)
        let caps = DeviceCapabilities(maxFPS: 60)

        let result = downgrader.downgrade(preset, capabilities: caps)
        #expect(result.wasDowngraded == true)
        #expect(result.adjustedPreset.settings.fps == 60)
    }

    @Test("Multi-cam mode downgrade when not supported")
    func testMultiCamDowngrade() {
        let settings = PresetSettings(cameraMode: "dualIndependent")
        let preset = Preset(id: "test", name: "Test", settings: settings)
        let caps = DeviceCapabilities(isMultiCamSupported: false)

        let result = downgrader.downgrade(preset, capabilities: caps)
        #expect(result.wasDowngraded == true)
        #expect(result.adjustedPreset.settings.cameraMode == "single")
    }

    @Test("Stabilization downgrade")
    func testStabilizationDowngrade() {
        let settings = PresetSettings(stabilization: "cinematic")
        let preset = Preset(id: "test", name: "Test", settings: settings)
        let caps = DeviceCapabilities(supportedStabilizationModes: ["off", "standard"])

        let result = downgrader.downgrade(preset, capabilities: caps)
        #expect(result.wasDowngraded == true)
        #expect(result.adjustedPreset.settings.stabilization == "off")
    }

    @Test("Torch downgrade when not available")
    func testTorchDowngrade() {
        let settings = PresetSettings(torchEnabled: true)
        let preset = Preset(id: "test", name: "Test", settings: settings)
        let caps = DeviceCapabilities(hasTorch: false)

        let result = downgrader.downgrade(preset, capabilities: caps)
        #expect(result.wasDowngraded == true)
        #expect(result.adjustedPreset.settings.torchEnabled == false)
    }

    @Test("Multiple simultaneous downgrades")
    func testMultipleDowngrades() {
        let settings = PresetSettings(
            resolution: "3840x2160",
            fps: 120,
            cameraMode: "tripleComposite",
            stabilization: "cinematic",
            torchEnabled: true
        )
        let preset = Preset(id: "test", name: "Test", settings: settings)
        let caps = DeviceCapabilities(
            supportedResolutions: ["1280x720"],
            maxFPS: 30,
            isMultiCamSupported: false,
            supportedStabilizationModes: ["off"],
            hasTorch: false
        )

        let result = downgrader.downgrade(preset, capabilities: caps)
        #expect(result.wasDowngraded == true)
        #expect(result.warnings.count == 5)
    }

    @Test("Preset identity preserved after downgrade")
    func testPresetIdentityPreserved() {
        let settings = PresetSettings(resolution: "3840x2160")
        let preset = Preset(id: "my-id", name: "My Name", template: .streaming4K30, isBuiltIn: true, settings: settings)
        let caps = DeviceCapabilities(supportedResolutions: ["1920x1080"])

        let result = downgrader.downgrade(preset, capabilities: caps)
        #expect(result.adjustedPreset.id == "my-id")
        #expect(result.adjustedPreset.name == "My Name")
        #expect(result.adjustedPreset.template == .streaming4K30)
        #expect(result.adjustedPreset.isBuiltIn == true)
    }
}
