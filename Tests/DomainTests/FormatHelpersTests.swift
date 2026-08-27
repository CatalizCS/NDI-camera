// FormatHelpersTests.swift
// DomainTests — Unit tests for FormatHelpers pure functions.
//
// These tests exercise format filtering, sorting, FPS extraction, and best-format selection.
// All tests operate on Domain value types only — no AVFoundation dependency.
// These tests can run on any platform (macOS, iOS Simulator, Linux).

import Testing
@testable import Domain

// MARK: - Test Data Factory

/// Creates test CaptureFormat instances with sensible defaults.
private func makeFormat(
    id: String = "test",
    width: Int = 1920,
    height: Int = 1080,
    fpsRanges: [FPSRange] = [FPSRange(minFrameRate: 1, maxFrameRate: 60)],
    stabilization: [StabilizationMode] = [.off, .standard],
    maxZoom: Double = 10.0,
    isVideoBinned: Bool = false,
    isMultiCamSupported: Bool = false,
    fieldOfView: Float = 65.0
) -> CaptureFormat {
    CaptureFormat(
        id: id,
        resolution: Resolution(width: width, height: height),
        fpsRanges: fpsRanges,
        pixelFormats: [.yuv420BiPlanarVideoRange],
        supportedStabilizationModes: stabilization,
        maxZoomFactor: maxZoom,
        videoZoomFactorUpscaleThreshold: 4.0,
        isVideoBinned: isVideoBinned,
        isMultiCamSupported: isMultiCamSupported,
        videoFieldOfView: fieldOfView,
        highResolutionStillImageDimensions: nil
    )
}

// MARK: - Resolution Tests

@Suite("Resolution")
struct ResolutionTests {

    @Test("pixel count calculation")
    func pixelCount() {
        let r = Resolution(width: 1920, height: 1080)
        #expect(r.pixelCount == 2_073_600)
    }

    @Test("aspect ratio calculation")
    func aspectRatio() {
        let r = Resolution(width: 1920, height: 1080)
        #expect(abs(r.aspectRatio - 16.0/9.0) < 0.001)
    }

    @Test("zero height returns zero aspect ratio")
    func zeroHeightAspectRatio() {
        let r = Resolution(width: 1920, height: 0)
        #expect(r.aspectRatio == 0)
    }

    @Test("comparable sorts by pixel count")
    func comparable() {
        let r720  = Resolution(width: 1280, height: 720)
        let r1080 = Resolution(width: 1920, height: 1080)
        let r4k   = Resolution(width: 3840, height: 2160)
        #expect(r720 < r1080)
        #expect(r1080 < r4k)
    }

    @Test("description format")
    func description() {
        let r = Resolution(width: 3840, height: 2160)
        #expect(r.description == "3840×2160")
    }
}

// MARK: - FPSRange Tests

@Suite("FPSRange")
struct FPSRangeTests {

    @Test("contains value within range")
    func containsWithin() {
        let range = FPSRange(minFrameRate: 1, maxFrameRate: 60)
        #expect(range.contains(30))
        #expect(range.contains(1))
        #expect(range.contains(60))
    }

    @Test("does not contain value outside range")
    func containsOutside() {
        let range = FPSRange(minFrameRate: 24, maxFrameRate: 60)
        #expect(!range.contains(23))
        #expect(!range.contains(61))
        #expect(!range.contains(120))
    }
}

// MARK: - CaptureFormat Tests

@Suite("CaptureFormat")
struct CaptureFormatTests {

    @Test("supports FPS within any range")
    func supportsFPS() {
        let format = makeFormat(fpsRanges: [
            FPSRange(minFrameRate: 1, maxFrameRate: 30),
            FPSRange(minFrameRate: 1, maxFrameRate: 60),
        ])
        #expect(format.supports(fps: 30))
        #expect(format.supports(fps: 60))
        #expect(!format.supports(fps: 120))
    }

    @Test("maxFrameRate returns highest across ranges")
    func maxFrameRate() {
        let format = makeFormat(fpsRanges: [
            FPSRange(minFrameRate: 1, maxFrameRate: 30),
            FPSRange(minFrameRate: 1, maxFrameRate: 60),
        ])
        #expect(format.maxFrameRate == 60)
    }

    @Test("maxFrameRate returns zero for empty ranges")
    func maxFrameRateEmpty() {
        let format = makeFormat(fpsRanges: [])
        #expect(format.maxFrameRate == 0)
    }
}

// MARK: - Format Filtering Tests

@Suite("Format Filtering")
struct FormatFilteringTests {

    let formats = [
        makeFormat(id: "720p30", width: 1280, height: 720,
                   fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 30)]),
        makeFormat(id: "1080p60", width: 1920, height: 1080,
                   fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 60)]),
        makeFormat(id: "1080p30_binned", width: 1920, height: 1080,
                   fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 30)],
                   isVideoBinned: true),
        makeFormat(id: "4k30", width: 3840, height: 2160,
                   fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 30)]),
        makeFormat(id: "4k60", width: 3840, height: 2160,
                   fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 60)]),
    ]

    @Test("filter by exact resolution")
    func filterByResolution() {
        let result = Domain.formats(
            matching: Resolution(width: 1920, height: 1080),
            from: formats
        )
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.resolution.width == 1920 })
    }

    @Test("filter by FPS support")
    func filterByFPS() {
        let result = Domain.formats(supportingFPS: 60, from: formats)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.supports(fps: 60) })
    }

    @Test("filter by minimum resolution")
    func filterByMinResolution() {
        let result = Domain.formats(
            atLeast: Resolution(width: 1920, height: 1080),
            from: formats
        )
        #expect(result.count == 4) // 1080p60, 1080p30_binned, 4k30, 4k60
    }

    @Test("filter non-binned formats")
    func filterNonBinned() {
        let result = nonBinnedFormats(from: formats)
        #expect(result.count == 4)
        #expect(result.allSatisfy { !$0.isVideoBinned })
    }

    @Test("filter empty input returns empty")
    func filterEmptyInput() {
        let result = Domain.formats(
            matching: Resolution(width: 1920, height: 1080),
            from: []
        )
        #expect(result.isEmpty)
    }

    @Test("filter with no matches returns empty")
    func filterNoMatches() {
        let result = Domain.formats(
            matching: Resolution(width: 7680, height: 4320),
            from: formats
        )
        #expect(result.isEmpty)
    }
}

// MARK: - Resolution Extraction Tests

@Suite("Resolution Extraction")
struct ResolutionExtractionTests {

    let formats = [
        makeFormat(id: "720p", width: 1280, height: 720),
        makeFormat(id: "1080p_a", width: 1920, height: 1080),
        makeFormat(id: "1080p_b", width: 1920, height: 1080),
        makeFormat(id: "4k", width: 3840, height: 2160),
    ]

    @Test("unique resolutions removes duplicates")
    func uniqueResolutions() {
        let result = Domain.uniqueResolutions(from: formats)
        #expect(result.count == 3)
    }

    @Test("unique resolutions sorted descending by pixel count")
    func uniqueResolutionsSorted() {
        let result = Domain.uniqueResolutions(from: formats)
        #expect(result.first?.width == 3840)
        #expect(result.last?.width == 1280)
    }

    @Test("unique resolutions from empty returns empty")
    func uniqueResolutionsEmpty() {
        let result = Domain.uniqueResolutions(from: [])
        #expect(result.isEmpty)
    }
}

// MARK: - FPS Extraction Tests

@Suite("FPS Extraction")
struct FPSExtractionTests {

    @Test("available FPS for a resolution")
    func availableFPSForResolution() {
        let formats = [
            makeFormat(id: "1080p30", width: 1920, height: 1080,
                       fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 30)]),
            makeFormat(id: "1080p60", width: 1920, height: 1080,
                       fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 60)]),
            makeFormat(id: "4k30", width: 3840, height: 2160,
                       fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 30)]),
        ]
        let result = Domain.availableFPS(
            for: Resolution(width: 1920, height: 1080),
            from: formats
        )
        #expect(result == [30, 60])
    }

    @Test("available FPS for non-existent resolution returns empty")
    func availableFPSNoMatch() {
        let formats = [
            makeFormat(id: "1080p", width: 1920, height: 1080,
                       fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 60)]),
        ]
        let result = Domain.availableFPS(
            for: Resolution(width: 7680, height: 4320),
            from: formats
        )
        #expect(result.isEmpty)
    }

    @Test("all available FPS across all formats")
    func allAvailableFPS() {
        let formats = [
            makeFormat(id: "a", fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 30)]),
            makeFormat(id: "b", fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 60)]),
            makeFormat(id: "c", fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 120)]),
        ]
        let result = Domain.allAvailableFPS(from: formats)
        #expect(result == [30, 60, 120])
    }
}

// MARK: - Format Sorting Tests

@Suite("Format Sorting")
struct FormatSortingTests {

    @Test("sorts by resolution descending, then non-binned, then FPS")
    func qualitySort() {
        let formats = [
            makeFormat(id: "720p", width: 1280, height: 720),
            makeFormat(id: "1080p_binned", width: 1920, height: 1080, isVideoBinned: true),
            makeFormat(id: "1080p", width: 1920, height: 1080),
            makeFormat(id: "4k", width: 3840, height: 2160),
        ]
        let sorted = sortedByQuality(formats)

        #expect(sorted[0].id == "4k")       // Highest resolution
        #expect(sorted[1].id == "1080p")     // Non-binned before binned
        #expect(sorted[2].id == "1080p_binned")
        #expect(sorted[3].id == "720p")
    }
}

// MARK: - Best Format Selection Tests

@Suite("Best Format Selection")
struct BestFormatSelectionTests {

    let formats = [
        makeFormat(id: "720p30", width: 1280, height: 720,
                   fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 30)]),
        makeFormat(id: "1080p60", width: 1920, height: 1080,
                   fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 60)]),
        makeFormat(id: "1080p30_binned", width: 1920, height: 1080,
                   fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 30)],
                   isVideoBinned: true),
        makeFormat(id: "4k30", width: 3840, height: 2160,
                   fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 30)]),
    ]

    @Test("exact resolution and FPS match returns best")
    func exactMatch() {
        let result = bestFormat(width: 1920, height: 1080, fps: 60, from: formats)
        #expect(result?.id == "1080p60")
    }

    @Test("prefers non-binned when both match resolution")
    func prefersNonBinned() {
        let result = bestFormat(width: 1920, height: 1080, fps: 30, from: formats)
        // Should prefer 1080p60 (non-binned, supports 30fps) over 1080p30_binned
        #expect(result?.isVideoBinned == false)
    }

    @Test("falls back to closest resolution when exact not available")
    func fallbackClosest() {
        let result = bestFormat(width: 2560, height: 1440, fps: 30, from: formats)
        #expect(result != nil) // Should find something close
    }

    @Test("returns nil for empty format list")
    func emptyFormats() {
        let result = bestFormat(width: 1920, height: 1080, fps: 60, from: [])
        #expect(result == nil)
    }

    @Test("matches 4K correctly")
    func fourKMatch() {
        let result = bestFormat(width: 3840, height: 2160, fps: 30, from: formats)
        #expect(result?.id == "4k30")
    }
}

// MARK: - Format Validation Tests

@Suite("Format Validation")
struct FormatValidationTests {

    @Test("valid FPS and stabilization combination")
    func validCombination() {
        let format = makeFormat(
            fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 60)],
            stabilization: [.off, .standard, .cinematic]
        )
        #expect(isValidCombination(format: format, fps: 30, stabilization: .standard))
        #expect(isValidCombination(format: format, fps: 60, stabilization: .cinematic))
    }

    @Test("invalid FPS rejects combination")
    func invalidFPS() {
        let format = makeFormat(
            fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 30)]
        )
        #expect(!isValidCombination(format: format, fps: 60, stabilization: .off))
    }

    @Test("unsupported stabilization rejects combination")
    func invalidStabilization() {
        let format = makeFormat(
            fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 60)],
            stabilization: [.off, .standard]
        )
        #expect(!isValidCombination(format: format, fps: 30, stabilization: .cinematicExtended))
    }

    @Test("stabilization off is always valid")
    func offAlwaysValid() {
        let format = makeFormat(
            fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 60)],
            stabilization: [.off]
        )
        #expect(isValidCombination(format: format, fps: 30, stabilization: .off))
    }

    @Test("combined FPS and stabilization filter")
    func combinedFilter() {
        let formats = [
            makeFormat(id: "a",
                       fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 60)],
                       stabilization: [.off, .standard]),
            makeFormat(id: "b",
                       fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 30)],
                       stabilization: [.off, .standard, .cinematic]),
            makeFormat(id: "c",
                       fpsRanges: [FPSRange(minFrameRate: 1, maxFrameRate: 120)],
                       stabilization: [.off]),
        ]

        let result = Domain.formats(
            supportingFPS: 60,
            andStabilization: .standard,
            from: formats
        )
        #expect(result.count == 1)
        #expect(result[0].id == "a")
    }
}

// MARK: - Model Codable Tests

@Suite("Model Codable")
struct ModelCodableTests {

    @Test("CameraDevice round-trips through JSON")
    func cameraDeviceCodable() throws {
        let device = CameraDevice(
            id: "device-1",
            name: "Back Wide Camera",
            position: .back,
            lensType: .wide,
            hasTorch: true,
            isFocusLockSupported: true,
            isExposureLockSupported: true,
            maxZoomFactor: 10.0,
            videoFieldOfView: 65.0
        )
        let data = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(CameraDevice.self, from: data)
        #expect(decoded == device)
    }

    @Test("CameraMode round-trips through JSON")
    func cameraModeCodable() throws {
        for mode in CameraMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(CameraMode.self, from: data)
            #expect(decoded == mode)
        }
    }

    @Test("VideoOrientation round-trips through JSON")
    func videoOrientationCodable() throws {
        for orientation in VideoOrientation.allCases {
            let data = try JSONEncoder().encode(orientation)
            let decoded = try JSONDecoder().decode(VideoOrientation.self, from: data)
            #expect(decoded == orientation)
        }
    }

    @Test("StabilizationMode round-trips through JSON")
    func stabilizationModeCodable() throws {
        for mode in StabilizationMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(StabilizationMode.self, from: data)
            #expect(decoded == mode)
        }
    }

    @Test("NormalizedPoint clamps values to 0-1 range")
    func normalizedPointClamping() {
        let p = NormalizedPoint(x: -0.5, y: 1.5)
        #expect(p.x == 0.0)
        #expect(p.y == 1.0)
    }

    @Test("NormalizedPoint center is 0.5, 0.5")
    func normalizedPointCenter() {
        let center = NormalizedPoint.center
        #expect(center.x == 0.5)
        #expect(center.y == 0.5)
    }

    @Test("TorchConfiguration clamps level")
    func torchConfigurationClamping() {
        let config = TorchConfiguration(isEnabled: true, level: 1.5)
        #expect(config.level == 1.0)
    }

    @Test("CameraMode camera count")
    func cameraModeCount() {
        #expect(CameraMode.single.cameraCount == 1)
        #expect(CameraMode.dualIndependent.cameraCount == 2)
        #expect(CameraMode.dualComposite.cameraCount == 2)
        #expect(CameraMode.tripleIndependent.cameraCount == 3)
        #expect(CameraMode.tripleComposite.cameraCount == 3)
    }

    @Test("CameraMode requiresMultiCam")
    func cameraModeRequiresMultiCam() {
        #expect(!CameraMode.single.requiresMultiCam)
        #expect(CameraMode.dualIndependent.requiresMultiCam)
        #expect(CameraMode.tripleComposite.requiresMultiCam)
    }
}

// MARK: - CameraState Tests

@Suite("CameraState")
struct CameraStateTests {

    @Test("default state has sensible values")
    func defaultState() {
        let state = CameraState()
        #expect(state.selectedDevice == nil)
        #expect(state.activeFormat == nil)
        #expect(state.targetFPS == 30)
        #expect(state.currentZoomFactor == 1.0)
        #expect(state.focusMode == .continuousAutoFocus)
        #expect(state.exposureMode == .continuousAutoExposure)
        #expect(state.exposureCompensation == 0)
        #expect(!state.isTorchActive)
        #expect(state.stabilizationMode == .off)
        #expect(state.videoOrientation == .auto)
        #expect(!state.isOrientationLocked)
        #expect(state.sessionState == .idle)
    }
}
