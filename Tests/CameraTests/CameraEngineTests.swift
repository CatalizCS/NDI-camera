// CameraEngineTests.swift
// CameraTests — Tests for Camera module internals.
//
// These tests exercise the AVFoundation mapping layer and camera engine configuration.
// They require the iOS/macOS SDK to compile (AVFoundation dependency).
// Run on an iOS Simulator or device.

import Testing
import AVFoundation
import CoreMedia
import CoreVideo
@testable import Camera
@testable import Domain

// MARK: - Device Mapper Tests

@Suite("DeviceMapper")
struct DeviceMapperTests {

    @Test("maps CameraPosition from AVCaptureDevice.Position")
    func positionMapping() {
        #expect(mapPosition(.front) == .front)
        #expect(mapPosition(.back) == .back)
        #expect(mapPosition(.unspecified) == .unspecified)
    }

    @Test("maps FocusMode round-trip")
    func focusModeRoundTrip() {
        for mode in FocusMode.allCases {
            let avMode = mapFocusMode(mode)
            let back = mapFocusMode(avMode)
            #expect(back == mode)
        }
    }

    @Test("maps ExposureMode round-trip")
    func exposureModeRoundTrip() {
        for mode in ExposureMode.allCases {
            let avMode = mapExposureMode(mode)
            let back = mapExposureMode(avMode)
            #expect(back == mode)
        }
    }

    @Test("maps StabilizationMode round-trip")
    func stabilizationModeRoundTrip() {
        for mode in StabilizationMode.allCases {
            let avMode = mapStabilizationMode(mode)
            let back = mapStabilizationMode(avMode)
            #expect(back == mode)
        }
    }

    @Test("maps VideoOrientation to AVCaptureVideoOrientation")
    func videoOrientationMapping() {
        #expect(mapVideoOrientation(.portrait) == .portrait)
        #expect(mapVideoOrientation(.landscapeLeft) == .landscapeLeft)
        #expect(mapVideoOrientation(.landscapeRight) == .landscapeRight)
        #expect(mapVideoOrientation(.auto) == .portrait) // auto defaults to portrait
    }
}

// MARK: - Format Mapper Tests

@Suite("FormatMapper")
struct FormatMapperTests {

    @Test("fourCC string conversion for known formats")
    func pixelFormatNames() {
        // We can verify the PixelFormat constants are correct
        #expect(PixelFormat.yuv420BiPlanarVideoRange.rawValue == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        #expect(PixelFormat.yuv420BiPlanarFullRange.rawValue == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        #expect(PixelFormat.bgra32.rawValue == kCVPixelFormatType_32BGRA)
    }
}

// MARK: - VideoFrame Tests

@Suite("VideoFrame")
struct VideoFrameTests {

    @Test("VideoFrame stores camera ID")
    func cameraIDStored() {
        // We can't easily create a CMSampleBuffer in a test without a device,
        // but we can verify the struct's interface exists and types match.
        // This is a compile-time verification test.
        let _: (CMSampleBuffer, CMTime, String) -> VideoFrame = VideoFrame.init
        // If this compiles, the struct has the expected signature.
    }
}

// MARK: - CameraError Tests

@Suite("CameraError")
struct CameraErrorTests {

    @Test("error descriptions are non-empty")
    func errorDescriptions() {
        let errors: [CameraError] = [
            .deviceNotFound(deviceID: "test"),
            .inputCreationFailed(reason: "test"),
            .formatNotAvailable(width: 1920, height: 1080, fps: 60),
            .sessionConfigurationFailed(reason: "test"),
            .torchNotAvailable,
            .stabilizationNotSupported(mode: .cinematic),
            .focusModeNotSupported(mode: .locked),
            .exposureModeNotSupported(mode: .custom),
            .zoomOutOfRange(requested: 20, min: 1, max: 10),
            .exposureCompensationOutOfRange(requested: 5, min: -2, max: 2),
            .cameraPermissionDenied,
            .cameraPermissionRestricted,
            .notInitialized,
            .sessionNotRunning,
            .sessionInterrupted(reason: "test"),
            .fpsNotSupported(requested: 240, maxAvailable: 60),
            .deviceConfigurationFailed(reason: "test"),
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("CameraError is Hashable for set membership")
    func hashable() {
        let a = CameraError.torchNotAvailable
        let b = CameraError.torchNotAvailable
        let c = CameraError.notInitialized
        #expect(a == b)
        #expect(a != c)
        let set: Set<CameraError> = [a, b, c]
        #expect(set.count == 2)
    }
}
