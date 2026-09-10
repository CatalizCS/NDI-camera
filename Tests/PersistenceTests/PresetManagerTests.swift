// PresetManagerTests.swift
// Tests for preset management, built-in presets, and CRUD operations.

import Testing
import Foundation
@testable import Persistence
@testable import Domain

@Suite("Preset Manager Tests")
struct PresetManagerTests {

    private func makeManager() -> PresetManager {
        let store = SettingsStore(suiteName: "com.tamandicam.tests.\(UUID().uuidString)")
        return PresetManager(settingsStore: store)
    }

    @Test("Built-in presets — 6 presets available")
    func testBuiltInPresetsCount() async {
        let manager = makeManager()
        let all = await manager.allPresets()
        #expect(all.count == 6)
    }

    @Test("Built-in presets — all marked as built-in")
    func testBuiltInPresetsFlag() {
        for preset in PresetManager.builtInPresets {
            #expect(preset.isBuiltIn == true)
        }
    }

    @Test("Built-in presets — have correct templates")
    func testBuiltInPresetsTemplates() {
        let templates = PresetManager.builtInPresets.compactMap(\.template)
        #expect(templates.count == 6)
        #expect(templates.contains(.streaming1080p60))
        #expect(templates.contains(.streaming4K30))
        #expect(templates.contains(.lowBandwidth))
        #expect(templates.contains(.highQuality))
        #expect(templates.contains(.dualCamera))
        #expect(templates.contains(.tripleComposite))
    }

    @Test("Load built-in preset")
    func testLoadBuiltInPreset() async throws {
        let manager = makeManager()
        let result = try await manager.loadPreset(id: PresetTemplate.streaming1080p60.rawValue)
        #expect(result.adjustedPreset.name == "Streaming 1080p60")
    }

    @Test("Load nonexistent preset — throws notFound")
    func testLoadNonexistentPreset() async {
        let manager = makeManager()
        do {
            let _ = try await manager.loadPreset(id: "nonexistent")
            #expect(Bool(false), "Should have thrown")
        } catch let error as PresetError {
            if case .notFound = error {
                // Expected
            } else {
                #expect(Bool(false), "Wrong error: \(error)")
            }
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }

    @Test("Save and load custom preset")
    func testSaveAndLoadCustomPreset() async throws {
        let manager = makeManager()
        let settings = PresetSettings(resolution: "1920x1080", fps: 60)
        let custom = Preset(id: "custom-1", name: "My Preset", settings: settings)
        try await manager.savePreset(custom)

        let all = await manager.allPresets()
        #expect(all.count == 7) // 6 built-in + 1 custom

        let result = try await manager.loadPreset(id: "custom-1")
        #expect(result.adjustedPreset.name == "My Preset")
    }

    @Test("Cannot save built-in preset")
    func testCannotSaveBuiltIn() async {
        let manager = makeManager()
        let preset = Preset(id: "test", name: "Test", isBuiltIn: true, settings: PresetSettings())
        do {
            try await manager.savePreset(preset)
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is PresetError)
        }
    }

    @Test("Delete custom preset")
    func testDeleteCustomPreset() async throws {
        let manager = makeManager()
        let custom = Preset(id: "custom-1", name: "My Preset", settings: PresetSettings())
        try await manager.savePreset(custom)
        try await manager.deletePreset(id: "custom-1")

        let all = await manager.allPresets()
        #expect(all.count == 6) // back to only built-in
    }

    @Test("Cannot delete built-in preset")
    func testCannotDeleteBuiltIn() async {
        let manager = makeManager()
        do {
            try await manager.deletePreset(id: PresetTemplate.streaming1080p60.rawValue)
            #expect(Bool(false), "Should have thrown")
        } catch let error as PresetError {
            if case .cannotModifyBuiltIn = error {
                // Expected
            } else {
                #expect(Bool(false), "Wrong error: \(error)")
            }
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }

    @Test("Export settings")
    func testExportSettings() async throws {
        let manager = makeManager()
        let snapshot = try await manager.exportSettings()
        #expect(snapshot.schemaVersion == 1)
    }
}
