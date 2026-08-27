// CameraEngine+Controls.swift
// Camera — Camera control methods: focus, exposure, zoom, torch, stabilization, orientation.
//
// Extension on CameraEngine providing all camera hardware control methods.
// Each method validates hardware support dynamically before applying changes.

import AVFoundation
import CoreGraphics
import Domain
import os

extension CameraEngine {

    // MARK: - Focus

    public func setFocus(mode: FocusMode, at point: NormalizedPoint?) async throws {
        guard let device = currentAVDevice else {
            throw CameraError.notInitialized
        }

        let avMode = mapFocusMode(mode)

        // Validate focus mode support
        guard device.isFocusModeSupported(avMode) else {
            throw CameraError.focusModeNotSupported(mode: mode)
        }

        try device.lockForConfiguration()

        // Set focus point of interest if the device supports it and a point is provided
        if let point, device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = CGPoint(x: point.x, y: point.y)
        }

        device.focusMode = avMode
        device.unlockForConfiguration()

        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: mode,
            exposureMode: $0.exposureMode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: $0.sessionState
        )}

        logger.info("Focus set: mode=\(mode.rawValue), point=\(String(describing: point))")
    }

    // MARK: - Exposure

    public func setExposure(mode: ExposureMode, at point: NormalizedPoint?) async throws {
        guard let device = currentAVDevice else {
            throw CameraError.notInitialized
        }

        let avMode = mapExposureMode(mode)

        // Validate exposure mode support
        guard device.isExposureModeSupported(avMode) else {
            throw CameraError.exposureModeNotSupported(mode: mode)
        }

        try device.lockForConfiguration()

        // Set exposure point of interest if supported and point is provided
        if let point, device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = CGPoint(x: point.x, y: point.y)
        }

        device.exposureMode = avMode
        device.unlockForConfiguration()

        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: $0.focusMode,
            exposureMode: mode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: $0.sessionState
        )}

        logger.info("Exposure set: mode=\(mode.rawValue)")
    }

    public func setExposureCompensation(_ ev: Float) async throws {
        guard let device = currentAVDevice else {
            throw CameraError.notInitialized
        }

        let minEV = device.minExposureTargetBias
        let maxEV = device.maxExposureTargetBias

        guard ev >= minEV && ev <= maxEV else {
            throw CameraError.exposureCompensationOutOfRange(
                requested: ev, min: minEV, max: maxEV
            )
        }

        try device.lockForConfiguration()
        device.setExposureTargetBias(ev, completionHandler: nil)
        device.unlockForConfiguration()

        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: $0.focusMode,
            exposureMode: $0.exposureMode,
            exposureCompensation: ev,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: $0.sessionState
        )}

        logger.info("Exposure compensation set: \(ev) EV")
    }

    // MARK: - Zoom

    public func setZoomFactor(_ factor: Double, animated: Bool) async throws {
        guard let device = currentAVDevice else {
            throw CameraError.notInitialized
        }

        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = device.maxAvailableVideoZoomFactor

        guard factor >= minZoom && factor <= maxZoom else {
            throw CameraError.zoomOutOfRange(
                requested: factor, min: minZoom, max: maxZoom
            )
        }

        try device.lockForConfiguration()

        if animated {
            device.ramp(toVideoZoomFactor: CGFloat(factor), withRate: 4.0)
        } else {
            device.videoZoomFactor = CGFloat(factor)
        }

        device.unlockForConfiguration()

        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: factor,
            focusMode: $0.focusMode,
            exposureMode: $0.exposureMode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: $0.sessionState
        )}

        logger.info("Zoom set: \(factor)x (animated: \(animated))")
    }

    // MARK: - Torch

    public func setTorch(_ configuration: TorchConfiguration) async throws {
        guard let device = currentAVDevice else {
            throw CameraError.notInitialized
        }

        guard device.hasTorch else {
            throw CameraError.torchNotAvailable
        }

        guard device.isTorchAvailable else {
            throw CameraError.torchNotAvailable
        }

        try device.lockForConfiguration()

        if configuration.isEnabled {
            if let level = configuration.level {
                try device.setTorchModeOn(level: level)
            } else {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            }
        } else {
            device.torchMode = .off
        }

        device.unlockForConfiguration()

        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: $0.focusMode,
            exposureMode: $0.exposureMode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: configuration.isEnabled,
            torchLevel: configuration.level ?? 1.0,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: $0.sessionState
        )}

        logger.info("Torch set: enabled=\(configuration.isEnabled), level=\(configuration.level ?? 1.0)")
    }

    // MARK: - Stabilization

    public func setStabilization(_ mode: StabilizationMode) async throws {
        guard let device = currentAVDevice else {
            throw CameraError.notInitialized
        }

        let avMode = mapStabilizationMode(mode)

        // Validate stabilization support on the active format
        guard mode == .off || device.activeFormat.isVideoStabilizationModeSupported(avMode) else {
            throw CameraError.stabilizationNotSupported(mode: mode)
        }

        // Stabilization is set on the AVCaptureConnection, not the device
        if let connection = videoOutput?.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = avMode
            }
        }

        _stabilizationMode = mode

        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: $0.focusMode,
            exposureMode: $0.exposureMode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: mode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: $0.sessionState
        )}

        logger.info("Stabilization set: \(mode.rawValue)")
    }

    // MARK: - Orientation

    public func setVideoOrientation(_ orientation: VideoOrientation) async throws {
        guard currentAVDevice != nil else {
            throw CameraError.notInitialized
        }

        guard !_isOrientationLocked else {
            logger.info("Orientation locked — ignoring change to \(orientation.rawValue)")
            return
        }

        applyVideoOrientation(orientation)
    }

    public func setOrientationLocked(_ locked: Bool) async throws {
        _isOrientationLocked = locked

        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: $0.focusMode,
            exposureMode: $0.exposureMode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: $0.videoOrientation,
            isOrientationLocked: locked,
            sessionState: $0.sessionState
        )}

        logger.info("Orientation lock: \(locked)")
    }

    // MARK: - Internal

    /// Apply a video orientation to the capture connection.
    internal func applyVideoOrientation(_ orientation: VideoOrientation) {
        _videoOrientation = orientation

        if let connection = videoOutput?.connection(with: .video) {
            let avOrientation = mapVideoOrientation(orientation)
            if connection.isVideoRotationAngleSupported(rotationAngle(for: avOrientation)) {
                connection.videoRotationAngle = rotationAngle(for: avOrientation)
            }
        }

        updateState { $0 = CameraState(
            selectedDevice: $0.selectedDevice,
            activeFormat: $0.activeFormat,
            targetFPS: $0.targetFPS,
            currentZoomFactor: $0.currentZoomFactor,
            focusMode: $0.focusMode,
            exposureMode: $0.exposureMode,
            exposureCompensation: $0.exposureCompensation,
            isTorchActive: $0.isTorchActive,
            torchLevel: $0.torchLevel,
            stabilizationMode: $0.stabilizationMode,
            videoOrientation: orientation,
            isOrientationLocked: $0.isOrientationLocked,
            sessionState: $0.sessionState
        )}
    }

    /// Convert an AVCaptureVideoOrientation to a rotation angle in degrees.
    private func rotationAngle(for orientation: AVCaptureVideoOrientation) -> CGFloat {
        switch orientation {
        case .portrait: 90
        case .portraitUpsideDown: 270
        case .landscapeRight: 0
        case .landscapeLeft: 180
        @unknown default: 0
        }
    }
}
