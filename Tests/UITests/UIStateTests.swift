// UIStateTests.swift
// Tests for UI view state, display modes, and AppCoordinator lifecycle.

import Testing
import Foundation
@testable import UI
@testable import Domain

@Suite("UI Coordinator & State Tests")
struct UIStateTests {

    @Test("Initial state defaults")
    @MainActor
    func testInitialCoordinatorState() {
        let coordinator = AppCoordinator()
        #expect(coordinator.isStreaming == false)
        #expect(coordinator.streamState == .idle)
        #expect(coordinator.displayMode == .normal)
        #expect(coordinator.remoteServerRunning == false)
        #expect(coordinator.thermalState == .nominal)
    }

    @Test("DisplayMode changes")
    @MainActor
    func testDisplayModeChanges() {
        let coordinator = AppCoordinator()
        coordinator.setDisplayMode(.dimmed)
        #expect(coordinator.displayMode == .dimmed)

        coordinator.setDisplayMode(.blacked)
        #expect(coordinator.displayMode == .blacked)

        coordinator.setDisplayMode(.normal)
        #expect(coordinator.displayMode == .normal)
    }

    @Test("DisplayMode all cases")
    func testDisplayModeCases() {
        let cases = DisplayMode.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.normal))
        #expect(cases.contains(.dimmed))
        #expect(cases.contains(.blacked))
    }

    @Test("CameraState defaults in coordinator")
    @MainActor
    func testCameraStateDefaults() {
        let coordinator = AppCoordinator()
        #expect(coordinator.cameraState.targetFPS == 30)
        #expect(coordinator.cameraState.currentZoomFactor == 1.0)
        #expect(coordinator.cameraState.isTorchActive == false)
        #expect(coordinator.cameraState.stabilizationMode == .off)
    }
}
