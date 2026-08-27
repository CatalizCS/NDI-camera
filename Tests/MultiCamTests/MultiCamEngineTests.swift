// MultiCamEngineTests.swift
// MultiCamTests — Unit tests for MultiCamEngine lifecycle, streams, and state transitions.

import Testing
import Foundation
import CoreMedia
@testable import MultiCam
@testable import Domain

// MARK: - MultiCam Engine Tests

@Suite("MultiCamEngine")
struct MultiCamEngineTests {

    @Test("MultiCamEngine initializes with default idle state")
    func engineInitialization() async {
        let engine = MultiCamEngine()
        let state = await engine.currentState()

        #expect(state.mode == .single)
        #expect(state.sessionState == .idle)
        #expect(state.activeSlots.isEmpty)
        #expect(state.hardwareCost == 0.0)
    }

    @Test("MultiCamEngine provides stream endpoints")
    func streamEndpoints() {
        let engine = MultiCamEngine()
        // Verify nonisolated async streams are accessible
        let _ = engine.independentFrames
        let _ = engine.compositeFrames
    }

    @Test("Setting composite layout updates state")
    func updateCompositeLayout() async throws {
        let engine = MultiCamEngine()
        let layout = CompositeLayout.sideBySide(splitRatio: 0.5, isVertical: false)

        try await engine.setCompositeLayout(layout)
        let state = await engine.currentState()

        #expect(state.layout == layout)
    }

    @Test("MultiCamCapabilityProviding reflects hardware support")
    func capabilityQuery() async {
        let engine = MultiCamEngine()
        let isSupported = await engine.isMultiCamSupported()
        #expect(isSupported == MultiCamCapabilityDetector.isMultiCamSupported)
    }
}
