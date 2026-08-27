// CameraDevice.swift
// Domain — Camera device descriptor.
// Maps a physical camera (lens) to a value type with no AVFoundation dependency.

import Foundation

// MARK: - Camera Position

/// Physical position of the camera on the device.
public enum CameraPosition: String, Sendable, Codable, CaseIterable, Hashable {
    case front
    case back
    case unspecified
}

// MARK: - Lens Type

/// Lens type classification. Discovered dynamically — never assume availability.
public enum LensType: String, Sendable, Codable, CaseIterable, Hashable {
    case ultraWide
    case wide
    case telephoto
    case trueDepth
    case unknown
}

// MARK: - Camera Device

/// Immutable descriptor for a physical camera device.
///
/// Created by mapping an `AVCaptureDevice` at discovery time.
/// Contains only value-type data — no AVFoundation references.
public struct CameraDevice: Sendable, Identifiable, Hashable, Codable {

    /// Stable unique identifier from `AVCaptureDevice.uniqueID`.
    public let id: String

    /// Human-friendly display name (e.g., "Back Ultra Wide Camera").
    public let name: String

    /// Physical position on the device body.
    public let position: CameraPosition

    /// Classified lens type.
    public let lensType: LensType

    /// Whether this device has a torch (flash).
    public let hasTorch: Bool

    /// Whether this device supports focus adjustment.
    public let isFocusLockSupported: Bool

    /// Whether this device supports exposure adjustment.
    public let isExposureLockSupported: Bool

    /// Maximum zoom factor reported by the device.
    public let maxZoomFactor: Double

    /// The default video field of view in degrees, if known.
    public let videoFieldOfView: Float?

    public init(
        id: String,
        name: String,
        position: CameraPosition,
        lensType: LensType,
        hasTorch: Bool,
        isFocusLockSupported: Bool,
        isExposureLockSupported: Bool,
        maxZoomFactor: Double,
        videoFieldOfView: Float?
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.lensType = lensType
        self.hasTorch = hasTorch
        self.isFocusLockSupported = isFocusLockSupported
        self.isExposureLockSupported = isExposureLockSupported
        self.maxZoomFactor = maxZoomFactor
        self.videoFieldOfView = videoFieldOfView
    }
}
