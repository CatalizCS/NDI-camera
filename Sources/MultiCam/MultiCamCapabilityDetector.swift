// MultiCamCapabilityDetector.swift
// MultiCam — Dynamic capability detection and hardware cost validation for AVCaptureMultiCamSession.
// Never assumes hardware configurations — dynamically checks device and session limits.

import AVFoundation
import CoreMedia
import Domain
import os

// MARK: - MultiCam Capability Detector

/// Discovers viable multi-camera hardware combinations and validates format/cost constraints at runtime.
public final class MultiCamCapabilityDetector: Sendable {

    /// Logger for capability diagnostics.
    private let logger = Logger(subsystem: "com.tamandicam", category: "MultiCamCapabilityDetector")

    public init() {}

    // MARK: - Hardware Support Query

    /// True if the current hardware supports simultaneous multi-camera capture.
    public static var isMultiCamSupported: Bool {
        AVCaptureMultiCamSession.isMultiCamSupported
    }

    /// Maximum hardware cost threshold allowed by iOS before dropping frames or rejecting session configuration.
    public static let maxHardwareCost: Float = 1.0

    // MARK: - Discovery

    /// Discovers all viable physical multi-camera combinations on the current device.
    /// Returns empty array if multi-cam is unsupported.
    public func discoverSupportedCombinations() -> [MultiCamDeviceCombination] {
        guard Self.isMultiCamSupported else {
            logger.info("AVCaptureMultiCamSession is not supported on this hardware.")
            return []
        }

        // Query all video capture devices
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera,
                .builtInTrueDepthCamera
            ],
            mediaType: .video,
            position: .unspecified
        )

        let avDevices = discoverySession.devices
        logger.info("MultiCam capability scan: found \(avDevices.count) physical devices")

        var combinations: [MultiCamDeviceCombination] = []

        // Map AV devices to Domain devices
        let domainDevices: [(av: AVCaptureDevice, domain: CameraDevice)] = avDevices.compactMap { avDevice in
            // Filter devices that have at least one multi-cam supported format
            let hasMultiCamFormat = avDevice.formats.contains { $0.isMultiCamSupported }
            guard hasMultiCamFormat else { return nil }

            let domainDev = CameraDevice(
                id: avDevice.uniqueID,
                name: avDevice.localizedName,
                position: mapPosition(avDevice.position),
                lensType: classifyLens(deviceType: avDevice.deviceType, position: avDevice.position),
                hasTorch: avDevice.hasTorch,
                isFocusLockSupported: avDevice.isFocusModeSupported(.locked),
                isExposureLockSupported: avDevice.isExposureModeSupported(.locked),
                maxZoomFactor: Double(avDevice.activeFormat.videoMaxZoomFactor),
                videoFieldOfView: avDevice.activeFormat.videoFieldOfView
            )
            return (avDevice, domainDev)
        }

        // 1. Dual combinations (Pairs of 2 devices)
        for i in 0..<domainDevices.count {
            for j in (i + 1)..<domainDevices.count {
                let pair = [domainDevices[i], domainDevices[j]]
                if let combo = evaluateCombination(pair) {
                    combinations.append(combo)
                }
            }
        }

        // 2. Triple combinations (Triplets of 3 devices where hardware permits)
        if domainDevices.count >= 3 {
            for i in 0..<domainDevices.count {
                for j in (i + 1)..<domainDevices.count {
                    for k in (j + 1)..<domainDevices.count {
                        let triplet = [domainDevices[i], domainDevices[j], domainDevices[k]]
                        if let combo = evaluateCombination(triplet) {
                            combinations.append(combo)
                        }
                    }
                }
            }
        }

        logger.info("Discovered \(combinations.count) valid multi-camera combinations")
        return combinations
    }

    // MARK: - Validation & Cost Calculation

    /// Evaluates a candidate device set to determine if it fits within hardware and format constraints.
    public func evaluateCombination(_ candidates: [(av: AVCaptureDevice, domain: CameraDevice)]) -> MultiCamDeviceCombination? {
        guard !candidates.isEmpty else { return nil }

        // All devices must have multi-cam supported formats
        let devices = candidates.map(\.domain)
        let avDevices = candidates.map(\.av)

        // Find common supported multi-cam resolutions across all devices
        let multiCamFormatSets: [[Resolution]] = avDevices.map { avDev in
            let multiCamFormats = avDev.formats.filter(\.isMultiCamSupported)
            let resolutions = multiCamFormats.map { format -> Resolution in
                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return Resolution(width: Int(dims.width), height: Int(dims.height))
            }
            return Array(Set(resolutions)).sorted(by: >)
        }

        guard let firstSet = multiCamFormatSets.first else { return nil }
        var commonResolutions = Set(firstSet)
        for set in multiCamFormatSets.dropFirst() {
            commonResolutions.formIntersection(set)
        }

        // Must support at least one resolution (e.g. 1080p, 720p, 4k)
        guard !commonResolutions.isEmpty else {
            return nil
        }

        // Calculate max supported FPS across all devices in multi-cam
        var maxFPS = 60.0
        for avDev in avDevices {
            let deviceMaxFPS = avDev.formats
                .filter(\.isMultiCamSupported)
                .flatMap(\.videoSupportedFrameRateRanges)
                .map(\.maxFrameRate)
                .max() ?? 30.0
            maxFPS = min(maxFPS, deviceMaxFPS)
        }

        // Compute estimated hardware cost score
        let sortedResolutions = commonResolutions.sorted(by: >)
        let cost = calculateCost(
            deviceCount: candidates.count,
            primaryResolution: sortedResolutions.first ?? Resolution(width: 1920, height: 1080),
            fps: min(maxFPS, 30.0)
        )

        guard cost <= Self.maxHardwareCost else {
            logger.debug("Combination [\(devices.map(\.name).joined(separator: ", "))] exceeded hardware cost: \(cost)")
            return nil
        }

        return MultiCamDeviceCombination(
            devices: devices,
            totalHardwareCost: cost,
            supportedResolutions: sortedResolutions,
            maxSupportedFPS: maxFPS
        )
    }

    /// Pure function for calculating estimated hardware resource cost score (0.0 to 1.0).
    /// Used for validation and budgeting before opening hardware sessions.
    public func calculateCost(deviceCount: Int, primaryResolution: Resolution, fps: Double) -> Float {
        // Base cost per camera sensor / ISP pipeline
        let sensorBaseCost: Float = Float(deviceCount) * 0.15

        // Pixel throughput cost (proportional to Megapixels per second)
        let megaPixels = Float(primaryResolution.pixelCount) / 1_000_000.0
        let pixelThroughput = megaPixels * Float(fps) * Float(deviceCount)

        // 1080p30 per camera = ~2 MP * 30 = 60 MP/s -> ~0.15 cost per camera
        // 4K30 per camera = ~8.3 MP * 30 = 250 MP/s -> ~0.35 cost per camera
        let throughputCost = (pixelThroughput / 300.0) * 0.40

        // Output buffer copy / color conversion cost
        let outputCost: Float = Float(deviceCount) * 0.05

        let totalCost = min(max(sensorBaseCost + throughputCost + outputCost, 0.1), 1.5)
        return totalCost
    }

    /// Validates a requested configuration against hardware and format constraints.
    public func validateConfiguration(
        slots: [MultiCamSlot: CameraDevice],
        formats: [MultiCamSlot: CaptureFormat],
        targetFPS: Double
    ) throws -> Float {
        guard !slots.isEmpty else {
            throw MultiCamError.unsupportedMode(mode: .single, reason: "No active slots specified")
        }

        if slots.count > 1 && !Self.isMultiCamSupported {
            throw MultiCamError.multiCamNotSupportedOnHardware
        }

        // Validate format multi-cam flags
        for (slot, format) in formats {
            guard format.isMultiCamSupported else {
                let devID = slots[slot]?.id ?? "unknown"
                throw MultiCamError.formatNotMultiCamSupported(deviceID: devID, formatID: format.id)
            }
        }

        let primaryRes = formats[.primary]?.resolution ?? Resolution(width: 1920, height: 1080)
        let cost = calculateCost(deviceCount: slots.count, primaryResolution: primaryRes, fps: targetFPS)

        if cost > Self.maxHardwareCost {
            throw MultiCamError.hardwareCostExceeded(currentCost: cost, maximumAllowed: Self.maxHardwareCost)
        }

        return cost
    }

    // MARK: - Private Mapping Helpers

    private func mapPosition(_ pos: AVCaptureDevice.Position) -> CameraPosition {
        switch pos {
        case .front: .front
        case .back: .back
        case .unspecified: .unspecified
        @unknown default: .unspecified
        }
    }

    private func classifyLens(deviceType: AVCaptureDevice.DeviceType, position: AVCaptureDevice.Position) -> LensType {
        switch deviceType {
        case .builtInUltraWideCamera:
            return .ultraWide
        case .builtInWideAngleCamera:
            return .wide
        case .builtInTelephotoCamera:
            return .telephoto
        case .builtInTrueDepthCamera:
            return .trueDepth
        default:
            return position == .front ? .trueDepth : .wide
        }
    }
}
