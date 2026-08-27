// MultiCamFallbackTests.swift
// MultiCamTests — Unit tests for MultiCamFallbackHandler and MultiCamDiagnostics.

import Testing
import Foundation
@testable import MultiCam
@testable import Domain

// MARK: - Helper Test Data

private func makeTestDevice(id: String, name: String, lens: LensType) -> CameraDevice {
    CameraDevice(
        id: id,
        name: name,
        position: .back,
        lensType: lens,
        hasTorch: true,
        isFocusLockSupported: true,
        isExposureLockSupported: true,
        maxZoomFactor: 5.0,
        videoFieldOfView: 65.0
    )
}

// MARK: - MultiCam Fallback Tests

@Suite("MultiCamFallbackHandler")
struct MultiCamFallbackTests {

    let fallbackHandler = MultiCamFallbackHandler()

    @Test("Falls back from Triple to Dual when cost budget exceeded")
    func tripleToDualFallback() {
        let dev1 = makeTestDevice(id: "wide", name: "Back Wide", lens: .wide)
        let dev2 = makeTestDevice(id: "ultra", name: "Back Ultra Wide", lens: .ultraWide)
        let dev3 = makeTestDevice(id: "tele", name: "Back Telephoto", lens: .telephoto)

        let slots: [MultiCamSlot: CameraDevice] = [
            .primary: dev1,
            .secondary: dev2,
            .tertiary: dev3
        ]

        let dualCombo = MultiCamDeviceCombination(
            devices: [dev1, dev2],
            totalHardwareCost: 0.60,
            supportedResolutions: [Resolution(width: 1920, height: 1080)],
            maxSupportedFPS: 30.0
        )

        let decision = fallbackHandler.negotiateFallback(
            requestedMode: .tripleIndependent,
            currentSlots: slots,
            availableCombinations: [dualCombo],
            reason: .costBudgetExceeded(cost: 1.15)
        )

        #expect(decision.targetMode == .dualIndependent)
        #expect(decision.retainedSlots[.primary]?.id == "wide")
        #expect(decision.retainedSlots[.secondary]?.id == "ultra")
        #expect(decision.retainedSlots[.tertiary] == nil)
    }

    @Test("Falls back to Single when multi-camera is not supported on hardware")
    func multiCamNotSupportedFallback() {
        let dev1 = makeTestDevice(id: "wide", name: "Back Wide", lens: .wide)
        let dev2 = makeTestDevice(id: "ultra", name: "Back Ultra Wide", lens: .ultraWide)

        let slots: [MultiCamSlot: CameraDevice] = [
            .primary: dev1,
            .secondary: dev2
        ]

        let decision = fallbackHandler.negotiateFallback(
            requestedMode: .dualComposite,
            currentSlots: slots,
            availableCombinations: [],
            reason: .multiCamNotSupported
        )

        #expect(decision.targetMode == .single)
        #expect(decision.retainedSlots.count == 1)
        #expect(decision.retainedSlots[.primary]?.id == "wide")
    }

    @Test("Falls back from Dual to Single when thermal pressure is high")
    func thermalPressureFallback() {
        let dev1 = makeTestDevice(id: "wide", name: "Back Wide", lens: .wide)
        let dev2 = makeTestDevice(id: "ultra", name: "Back Ultra Wide", lens: .ultraWide)

        let slots: [MultiCamSlot: CameraDevice] = [
            .primary: dev1,
            .secondary: dev2
        ]

        let decision = fallbackHandler.negotiateFallback(
            requestedMode: .dualIndependent,
            currentSlots: slots,
            availableCombinations: [],
            reason: .thermalPressureHigh
        )

        #expect(decision.targetMode == .single)
        #expect(decision.retainedSlots[.primary]?.id == "wide")
    }
}

// MARK: - MultiCam Diagnostics Tests

@Suite("MultiCamDiagnosticsCollector")
struct MultiCamDiagnosticsTests {

    @Test("Collector records frames, calculates FPS, and captures drop events")
    func diagnosticsCollection() async {
        let collector = MultiCamDiagnosticsCollector()
        await collector.updateState(mode: .dualComposite, hardwareCost: 0.55, isThrottled: false)

        // Record synthetic frames
        let baseTime = 100.0
        for i in 0..<30 {
            let t = baseTime + (Double(i) / 30.0)
            await collector.recordFrame(for: .primary, at: t)
            await collector.recordFrame(for: .secondary, at: t + 0.005)
        }

        await collector.recordDrop(for: .secondary)
        await collector.recordCompositeFrame(driftMs: 5.0)

        let snapshot = await collector.snapshot()

        #expect(snapshot.mode == .dualComposite)
        #expect(snapshot.activeSlotsCount == 2)
        #expect(snapshot.perSlotDrops[.secondary] == 1)
        #expect(snapshot.totalCompositeFrames == 1)
        #expect(snapshot.hardwareCost == 0.55)
        #expect(!snapshot.isThrottled)

        if let fpsPrimary = snapshot.perSlotFPS[.primary] {
            #expect(abs(fpsPrimary - 30.0) < 1.5)
        }
    }
}
