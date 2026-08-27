// CaptureFormat.swift
// Domain — Capture format descriptor.
// Represents a camera capture format with resolution, FPS ranges, and capabilities.

import Foundation

// MARK: - Resolution

/// Video resolution in pixels.
public struct Resolution: Sendable, Hashable, Codable, CustomStringConvertible {
    public let width: Int
    public let height: Int

    public var pixelCount: Int { width * height }

    public var description: String { "\(width)×\(height)" }

    public var aspectRatio: Double {
        guard height > 0 else { return 0 }
        return Double(width) / Double(height)
    }

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

extension Resolution: Comparable {
    public static func < (lhs: Resolution, rhs: Resolution) -> Bool {
        lhs.pixelCount < rhs.pixelCount
    }
}

// MARK: - FPS Range

/// Frame rate range supported by a capture format.
public struct FPSRange: Sendable, Hashable, Codable {
    public let minFrameRate: Double
    public let maxFrameRate: Double

    /// Whether this range includes a specific frame rate.
    public func contains(_ fps: Double) -> Bool {
        fps >= minFrameRate && fps <= maxFrameRate
    }

    public init(minFrameRate: Double, maxFrameRate: Double) {
        self.minFrameRate = minFrameRate
        self.maxFrameRate = maxFrameRate
    }
}

// MARK: - Pixel Format

/// Pixel format identifier. Mirrors `OSType` / FourCC constants from CoreVideo.
public struct PixelFormat: Sendable, Hashable, Codable {
    /// Raw FourCC value (e.g., `kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange`).
    public let rawValue: UInt32

    /// Human-readable name for display.
    public let displayName: String

    public init(rawValue: UInt32, displayName: String) {
        self.rawValue = rawValue
        self.displayName = displayName
    }

    // Well-known formats for reference — actual availability is discovered at runtime.
    public static let yuv420BiPlanarVideoRange = PixelFormat(rawValue: 0x3432_3076, displayName: "420v (YUV Video Range)")
    public static let yuv420BiPlanarFullRange  = PixelFormat(rawValue: 0x3432_3066, displayName: "420f (YUV Full Range)")
    public static let bgra32                   = PixelFormat(rawValue: 0x42475241, displayName: "BGRA 32-bit")
}

// MARK: - Capture Format

/// Immutable descriptor for a camera capture format.
///
/// Created by mapping an `AVCaptureDevice.Format` at discovery time.
/// Contains only value-type data — no AVFoundation references.
public struct CaptureFormat: Sendable, Identifiable, Hashable {

    /// Unique identifier derived from format properties.
    public let id: String

    /// Native resolution of this format.
    public let resolution: Resolution

    /// All supported frame rate ranges.
    public let fpsRanges: [FPSRange]

    /// Supported pixel format types.
    public let pixelFormats: [PixelFormat]

    /// Video stabilization modes supported by this format.
    public let supportedStabilizationModes: [StabilizationMode]

    /// Maximum zoom factor available in this format.
    public let maxZoomFactor: Double

    /// Zoom factor at which upscaling begins.
    public let videoZoomFactorUpscaleThreshold: Double

    /// Whether this format is binned (lower quality but lower power).
    public let isVideoBinned: Bool

    /// Whether this format supports multi-camera sessions.
    public let isMultiCamSupported: Bool

    /// Horizontal field of view in degrees.
    public let videoFieldOfView: Float

    /// Maximum supported photo resolution dimensions for this format, if available.
    public let highResolutionStillImageDimensions: Resolution?

    /// The maximum frame rate achievable across all FPS ranges.
    public var maxFrameRate: Double {
        fpsRanges.map(\.maxFrameRate).max() ?? 0
    }

    /// Whether the format supports a specific frame rate.
    public func supports(fps: Double) -> Bool {
        fpsRanges.contains { $0.contains(fps) }
    }

    public init(
        id: String,
        resolution: Resolution,
        fpsRanges: [FPSRange],
        pixelFormats: [PixelFormat],
        supportedStabilizationModes: [StabilizationMode],
        maxZoomFactor: Double,
        videoZoomFactorUpscaleThreshold: Double,
        isVideoBinned: Bool,
        isMultiCamSupported: Bool,
        videoFieldOfView: Float,
        highResolutionStillImageDimensions: Resolution?
    ) {
        self.id = id
        self.resolution = resolution
        self.fpsRanges = fpsRanges
        self.pixelFormats = pixelFormats
        self.supportedStabilizationModes = supportedStabilizationModes
        self.maxZoomFactor = maxZoomFactor
        self.videoZoomFactorUpscaleThreshold = videoZoomFactorUpscaleThreshold
        self.isVideoBinned = isVideoBinned
        self.isMultiCamSupported = isMultiCamSupported
        self.videoFieldOfView = videoFieldOfView
        self.highResolutionStillImageDimensions = highResolutionStillImageDimensions
    }
}
