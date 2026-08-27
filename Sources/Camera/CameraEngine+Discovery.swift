// CameraEngine+Discovery.swift
// Camera — Dynamic capability and device discovery.
//
// All capabilities are discovered at runtime from actual hardware.
// Nothing is hard-coded or assumed about available lenses, resolutions, or FPS ranges.

import AVFoundation
import Domain
import os

extension CameraEngine {

    // MARK: - CameraCapabilityProviding

    public func availableDevices() async -> [CameraDevice] {
        if discoveredDevices.isEmpty {
            discoveredDevices = discoverAllDevices()
        }
        return discoveredDevices
    }

    public func supportedFormats(for device: CameraDevice) async -> [CaptureFormat] {
        guard let avDevice = AVCaptureDevice(uniqueID: device.id) else {
            return []
        }
        return mapFormats(from: avDevice)
    }

    public func supportedStabilizationModes(for format: CaptureFormat) async -> [StabilizationMode] {
        format.supportedStabilizationModes
    }

    public func isTorchAvailable() async -> Bool {
        guard let device = currentAVDevice else { return false }
        return device.hasTorch && device.isTorchAvailable
    }

    public func minZoomFactor() async -> Double {
        guard let device = currentAVDevice else { return 1.0 }
        return device.minAvailableVideoZoomFactor
    }

    public func maxZoomFactor() async -> Double {
        guard let device = currentAVDevice else { return 1.0 }
        return device.maxAvailableVideoZoomFactor
    }

    public func exposureCompensationRange() async -> ClosedRange<Float> {
        guard let device = currentAVDevice else { return 0...0 }
        return device.minExposureTargetBias...device.maxExposureTargetBias
    }

    public func capabilities() async -> CameraCapability {
        let devices = await availableDevices()
        let isMultiCamSupported = AVCaptureMultiCamSession.isMultiCamSupported

        var supportedModes: [CameraMode] = [.single]

        if isMultiCamSupported {
            // Discover viable multi-cam combinations dynamically.
            // We check the actual multi-cam device sets supported by the hardware.
            let multiCamDeviceSets = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
                mediaType: .video,
                position: .unspecified
            ).supportedMultiCamDeviceSets

            if multiCamDeviceSets.contains(where: { $0.count >= 2 }) {
                supportedModes.append(contentsOf: [.dualIndependent, .dualComposite])
            }
            if multiCamDeviceSets.contains(where: { $0.count >= 3 }) {
                supportedModes.append(contentsOf: [.tripleIndependent, .tripleComposite])
            }
        }

        return CameraCapability(
            devices: devices,
            isMultiCamSupported: isMultiCamSupported,
            supportedModes: supportedModes
        )
    }

    // MARK: - Device Discovery

    /// Discover all available camera devices using AVCaptureDevice.DiscoverySession.
    ///
    /// Queries all known built-in camera device types. The results reflect
    /// what the actual hardware provides — no assumptions about lens availability.
    internal func discoverAllDevices() -> [CameraDevice] {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera,
            .builtInTrueDepthCamera,
        ]

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )

        let devices = discovery.devices.map { mapDevice($0) }

        logger.info("Device discovery: found \(devices.count) device(s)")
        for device in devices {
            logger.info("  - \(device.name) [\(device.lensType.rawValue)] (\(device.position.rawValue))")
        }

        return devices
    }

    /// Get all available formats for the currently selected device.
    internal func formatsForCurrentDevice() -> [CaptureFormat] {
        currentDeviceFormats
    }
}
