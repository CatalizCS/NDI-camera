// DeviceMapper.swift
// Camera — Maps AVCaptureDevice to Domain CameraDevice.
//
// This is the single point where AVFoundation device objects are translated
// into the Domain's pure value types. No AVFoundation types leak beyond this boundary.

import AVFoundation
import Domain

// MARK: - Device Mapping

/// Map an `AVCaptureDevice` to a Domain `CameraDevice`.
func mapDevice(_ device: AVCaptureDevice) -> CameraDevice {
    CameraDevice(
        id: device.uniqueID,
        name: device.localizedName,
        position: mapPosition(device.position),
        lensType: classifyLens(device),
        hasTorch: device.hasTorch,
        isFocusLockSupported: device.isFocusPointOfInterestSupported,
        isExposureLockSupported: device.isExposurePointOfInterestSupported,
        maxZoomFactor: device.maxAvailableVideoZoomFactor,
        videoFieldOfView: device.activeFormat.videoFieldOfView
    )
}

/// Map `AVCaptureDevice.Position` to `CameraPosition`.
func mapPosition(_ position: AVCaptureDevice.Position) -> CameraPosition {
    switch position {
    case .front: .front
    case .back: .back
    case .unspecified: .unspecified
    @unknown default: .unspecified
    }
}

/// Classify a device's lens type based on its `AVCaptureDevice.DeviceType`.
func classifyLens(_ device: AVCaptureDevice) -> LensType {
    switch device.deviceType {
    case .builtInUltraWideCamera: .ultraWide
    case .builtInWideAngleCamera: .wide
    case .builtInTelephotoCamera: .telephoto
    case .builtInTrueDepthCamera: .trueDepth
    default: .unknown
    }
}

// MARK: - Focus Mode Mapping

/// Map Domain `FocusMode` to `AVCaptureDevice.FocusMode`.
func mapFocusMode(_ mode: FocusMode) -> AVCaptureDevice.FocusMode {
    switch mode {
    case .locked: .locked
    case .autoFocus: .autoFocus
    case .continuousAutoFocus: .continuousAutoFocus
    }
}

/// Map `AVCaptureDevice.FocusMode` to Domain `FocusMode`.
func mapFocusMode(_ mode: AVCaptureDevice.FocusMode) -> FocusMode {
    switch mode {
    case .locked: .locked
    case .autoFocus: .autoFocus
    case .continuousAutoFocus: .continuousAutoFocus
    @unknown default: .continuousAutoFocus
    }
}

// MARK: - Exposure Mode Mapping

/// Map Domain `ExposureMode` to `AVCaptureDevice.ExposureMode`.
func mapExposureMode(_ mode: ExposureMode) -> AVCaptureDevice.ExposureMode {
    switch mode {
    case .locked: .locked
    case .autoExpose: .autoExpose
    case .continuousAutoExposure: .continuousAutoExposure
    case .custom: .custom
    }
}

/// Map `AVCaptureDevice.ExposureMode` to Domain `ExposureMode`.
func mapExposureMode(_ mode: AVCaptureDevice.ExposureMode) -> ExposureMode {
    switch mode {
    case .locked: .locked
    case .autoExpose: .autoExpose
    case .continuousAutoExposure: .continuousAutoExposure
    case .custom: .custom
    @unknown default: .continuousAutoExposure
    }
}

// MARK: - Stabilization Mode Mapping

/// Map Domain `StabilizationMode` to `AVCaptureVideoStabilizationMode`.
func mapStabilizationMode(_ mode: StabilizationMode) -> AVCaptureVideoStabilizationMode {
    switch mode {
    case .off: .off
    case .standard: .standard
    case .cinematic: .cinematic
    case .cinematicExtended: .cinematicExtended
    case .auto: .auto
    }
}

/// Map `AVCaptureVideoStabilizationMode` to Domain `StabilizationMode`.
func mapStabilizationMode(_ mode: AVCaptureVideoStabilizationMode) -> StabilizationMode {
    switch mode {
    case .off: .off
    case .standard: .standard
    case .cinematic: .cinematic
    case .cinematicExtended: .cinematicExtended
    case .auto: .auto
    @unknown default: .off
    }
}

// MARK: - Video Orientation Mapping

/// Map Domain `VideoOrientation` to `AVCaptureVideoOrientation`.
///
/// For `.auto`, returns `.portrait` as a default — the caller is responsible
/// for reading the device orientation and choosing the appropriate value.
func mapVideoOrientation(_ orientation: VideoOrientation) -> AVCaptureVideoOrientation {
    switch orientation {
    case .auto: .portrait
    case .portrait: .portrait
    case .landscapeLeft: .landscapeLeft
    case .landscapeRight: .landscapeRight
    }
}
