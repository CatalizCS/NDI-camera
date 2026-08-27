// MultiCamCapabilityTests.swift
// MultiCamTests — Unit tests for MultiCamCapabilityDetector and hardware resource cost estimation.

import Testing
import Foundation
@testable import MultiCam
@testable import Domain

// MARK: - Helper Test Data

private func makeTestDevice(id: String, name: String, lens: LensType, pos: CameraPosition = .back) -> CameraDevice {
    CameraDevice(
        id: id,
        name: name,
        position: pos,
        lensType: lens,
        hasTorch: pos == .back,
        isFocusLockSupported: true,
        isExposureLockSupported: true,
        maxZoomFactor: 10.0,
        videoFieldOfView: 65.0
    )
}

private func makeTestFormat(id: String, res: Resolution, isMultiCam: Bool = true, maxFPS: Double = 60.0) -> CaptureFormat {
    CaptureFormat(
        id: id,
        resolution: res,
        fpsRanges: [FPSRange(minFrameRate: 1.0, maxFrameRate: maxFPS)],
        pixelFormats: [.yuv420BiPlanarVideoRange],
        supportedStabilizationModes: [.off, .standard],
        maxZoomFactor: 5.0,
        videoZoomFactorUpscaleThreshold: 2.0,
        isVideoBinned: false,
        isMultiCamSupported: isMultiCam,
        videoFieldOfView: 65.0,
        highResolutionStillImageDimensions: nil
    )
}

// MARK: - MultiCam Capability Tests

@Suite("MultiCamCapabilityDetector")
struct MultiCamCapabilityTests {

    let detector = MultiCamCapabilityDetector()

    @Test("Hardware cost scales appropriately with device count and resolution")
    func hardwareCostScaling() {
        let single1080pCost = detector.calculateCost(
            deviceCount: 1,
            primaryResolution: Resolution(width: 1920, height: 1080),
            fps: 30.0
        )
        let dual1080pCost = detector.calculateCost(
            deviceCount: 2,
            primaryResolution: Resolution(width: 1920, height: 1080),
            fps: 30.0
        )
        let triple1080pCost = detector.calculateCost(
            deviceCount: 3,
            primaryResolution: Resolution(width: 1920, height: 1080),
            fps: 30.0
        )

        #expect(single1080pCost < dual1080pCost)
        #expect(dual1080pCost < triple1080pCost)
        #expect(dual1080pCost <= 1.0)
        #expect(triple1080pCost <= 1.0)
    }

    @Test("4K high frame rate multi-cam triggers cost limit")
    func excessiveCostCalculation() {
        // 3 cameras at 4K 60fps should exceed cost 1.0
        let extremeCost = detector.calculateCost(
            deviceCount: 3,
            primaryResolution: Resolution(width: 3840, height: 2160),
            fps: 60.0
        )
        #expect(extremeCost > 1.0)
    }

    @Test("validateConfiguration passes for viable dual 1080p30 configuration")
    func validateViableConfiguration() throws {
        let dev1 = makeTestDevice(id: "wide", name: "Wide", lens: .wide)
        let dev2 = makeTestDevice(id: "ultra", name: "Ultra", lens: .ultraWide)
        let fmt1 = makeTestFormat(id: "1080p30_1", res: Resolution(width: 1920, height: 1080), isMultiCam: true)
        let fmt2 = makeTestFormat(id: "1080p30_2", res: Resolution(width: 1920, height: 1080), isMultiCam: true)

        let slots: [MultiCamSlot: CameraDevice] = [.primary: dev1, .secondary: dev2]
        let formats: [MultiCamSlot: CaptureFormat] = [.primary: fmt1, .secondary: fmt2]

        // On hardware that supports multi-cam or simulation:
        if MultiCamCapabilityDetector.isMultiCamSupported {
            let cost = try detector.validateConfiguration(slots: slots, formats: formats, targetFPS: 30.0)
            #expect(cost <= 1.0)
        }
    }

    @Test("validateConfiguration rejects format when isMultiCamSupported is false")
    func rejectNonMultiCamFormat() {
        let dev1 = makeTestDevice(id: "wide", name: "Wide", lens: .wide)
        let dev2 = makeTestDevice(id: "ultra", name: "Ultra", lens: .ultraWide)
        let fmt1 = makeTestFormat(id: "1080p30", res: Resolution(width: 1920, height: 1080), isMultiCam: true)
        let fmt2 = makeTestFormat(id: "unsupported_fmt", res: Resolution(width: 1920, height: 1080), isMultiCam: false)

        let slots: [MultiCamSlot: CameraDevice] = [.primary: dev1, .secondary: dev2]
        let formats: [MultiCamSlot: CaptureFormat] = [.primary: fmt1, .secondary: fmt2]

        if MultiCamCapabilityDetector.isMultiCamSupported {
            #expect(throws: MultiCamError.self) {
                try detector.validateConfiguration(slots: slots, formats: formats, targetFPS: 30.0)
            }
        }
    }
}
