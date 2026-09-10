// SettingsStoreTests.swift
// Tests for UserDefaults-backed settings store.

import Testing
import Foundation
@testable import Persistence
@testable import Domain

@Suite("Settings Store Tests")
struct SettingsStoreTests {

    private func makeStore() -> SettingsStore {
        SettingsStore(suiteName: "com.tamandicam.tests.\(UUID().uuidString)")
    }

    @Test("Default settings — all nil")
    func testDefaultSettings() async {
        let store = makeStore()
        let settings = await store.currentSettings()
        #expect(settings.resolution == nil)
        #expect(settings.fps == nil)
        #expect(settings.cameraMode == nil)
        #expect(settings.torchEnabled == nil)
    }

    @Test("Apply and read settings")
    func testApplyAndRead() async throws {
        let store = makeStore()
        let settings = PresetSettings(
            resolution: "1920x1080",
            fps: 60,
            cameraMode: "single",
            torchEnabled: false,
            audioMuted: true
        )
        try await store.applySettings(settings)

        let read = await store.currentSettings()
        #expect(read.resolution == "1920x1080")
        #expect(read.fps == 60)
        #expect(read.cameraMode == "single")
        #expect(read.torchEnabled == false)
        #expect(read.audioMuted == true)
    }

    @Test("Reset to defaults clears all settings")
    func testResetToDefaults() async throws {
        let store = makeStore()
        let settings = PresetSettings(resolution: "3840x2160", fps: 30)
        try await store.applySettings(settings)

        await store.resetToDefaults()

        let read = await store.currentSettings()
        #expect(read.resolution == nil)
        #expect(read.fps == nil)
    }

    @Test("Partial settings update — only specified values change")
    func testPartialUpdate() async throws {
        let store = makeStore()

        // First apply
        try await store.applySettings(PresetSettings(resolution: "1920x1080", fps: 60))

        // Second apply — only FPS changes
        try await store.applySettings(PresetSettings(fps: 30))

        let read = await store.currentSettings()
        #expect(read.resolution == "1920x1080") // Unchanged
        #expect(read.fps == 30)                  // Updated
    }

    @Test("NDI settings persistence")
    func testNDISettingsPersistence() async throws {
        let store = makeStore()
        let settings = PresetSettings(ndiSourceName: "MyCamera", ndiGroup: "Production")
        try await store.applySettings(settings)

        let read = await store.currentSettings()
        #expect(read.ndiSourceName == "MyCamera")
        #expect(read.ndiGroup == "Production")
    }
}
