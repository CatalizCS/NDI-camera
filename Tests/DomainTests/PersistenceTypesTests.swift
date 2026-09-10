// PersistenceTypesTests.swift

import Testing
@testable import Domain

@Suite("Persistence Types Tests")
struct PersistenceTypesTests {

    @Test("PresetTemplate all cases")
    func testPresetTemplateAllCases() {
        #expect(PresetTemplate.allCases.count == 6)
    }

    @Test("PresetTemplate display names")
    func testPresetTemplateDisplayNames() {
        #expect(PresetTemplate.streaming1080p60.displayName == "Streaming 1080p60")
        #expect(PresetTemplate.streaming4K30.displayName == "Streaming 4K30")
        #expect(PresetTemplate.lowBandwidth.displayName == "Low Bandwidth")
        #expect(PresetTemplate.highQuality.displayName == "High Quality")
        #expect(PresetTemplate.dualCamera.displayName == "Dual Camera")
        #expect(PresetTemplate.tripleComposite.displayName == "Triple Composite")
    }

    @Test("PresetTemplate identifiable")
    func testPresetTemplateIdentifiable() {
        #expect(PresetTemplate.streaming1080p60.id == "streaming_1080p60")
    }

    @Test("Preset Codable roundtrip")
    func testPresetCodable() throws {
        let settings = PresetSettings(resolution: "1920x1080", fps: 60, cameraMode: "single")
        let preset = Preset(id: "p1", name: "Test", template: .streaming1080p60, isBuiltIn: true, settings: settings)
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(Preset.self, from: data)
        #expect(decoded == preset)
    }

    @Test("PresetDowngradeResult no warnings means not downgraded")
    func testDowngradeNoWarnings() {
        let settings = PresetSettings(resolution: "1920x1080")
        let preset = Preset(id: "p1", name: "Test", settings: settings)
        let result = PresetDowngradeResult(adjustedPreset: preset, warnings: [])
        #expect(result.wasDowngraded == false)
    }

    @Test("PresetDowngradeResult with warnings means downgraded")
    func testDowngradeWithWarnings() {
        let settings = PresetSettings(resolution: "1280x720")
        let preset = Preset(id: "p1", name: "Test", settings: settings)
        let result = PresetDowngradeResult(adjustedPreset: preset, warnings: ["Resolution downgraded from 4K to 720p"])
        #expect(result.wasDowngraded == true)
        #expect(result.warnings.count == 1)
    }

    @Test("SettingsSnapshot Codable roundtrip")
    func testSettingsSnapshotCodable() throws {
        let settings = PresetSettings(fps: 30)
        let snapshot = SettingsSnapshot(schemaVersion: 1, settings: settings, presets: [])
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SettingsSnapshot.self, from: data)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.presets.isEmpty)
    }
}
