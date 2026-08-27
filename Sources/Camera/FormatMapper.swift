// FormatMapper.swift
// Camera — Maps AVCaptureDevice.Format to Domain CaptureFormat.
//
// Translates AVFoundation capture format objects into pure value types.
// All format discovery is dynamic — never hard-coded.

import AVFoundation
import CoreMedia
import CoreVideo
import Domain

// MARK: - Format Mapping

/// Map an `AVCaptureDevice.Format` to a Domain `CaptureFormat`.
///
/// - Parameters:
///   - format: The AVFoundation format to map.
///   - index: A disambiguation index for the format ID.
/// - Returns: A `CaptureFormat` with all properties discovered from the actual format.
func mapFormat(_ format: AVCaptureDevice.Format, index: Int) -> CaptureFormat {
    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
    let resolution = Resolution(width: Int(dimensions.width), height: Int(dimensions.height))

    let fpsRanges = format.videoSupportedFrameRateRanges.map { range in
        FPSRange(
            minFrameRate: range.minFrameRate,
            maxFrameRate: range.maxFrameRate
        )
    }

    let pixelFormats = discoverPixelFormats(from: format)
    let stabilizationModes = discoverStabilizationModes(from: format)
    let highResDimensions = discoverHighResDimensions(from: format)

    let formatID = "\(dimensions.width)x\(dimensions.height)_\(index)"

    return CaptureFormat(
        id: formatID,
        resolution: resolution,
        fpsRanges: fpsRanges,
        pixelFormats: pixelFormats,
        supportedStabilizationModes: stabilizationModes,
        maxZoomFactor: format.videoMaxZoomFactor,
        videoZoomFactorUpscaleThreshold: format.videoZoomFactorUpscaleThreshold,
        isVideoBinned: format.isVideoBinned,
        isMultiCamSupported: format.isMultiCamSupported,
        videoFieldOfView: format.videoFieldOfView,
        highResolutionStillImageDimensions: highResDimensions
    )
}

/// Map all formats of a device to Domain `CaptureFormat` values.
func mapFormats(from device: AVCaptureDevice) -> [CaptureFormat] {
    device.formats.enumerated().map { index, format in
        mapFormat(format, index: index)
    }
}

// MARK: - Pixel Format Discovery

/// Discover pixel formats from a capture format's description.
private func discoverPixelFormats(from format: AVCaptureDevice.Format) -> [PixelFormat] {
    // The format description contains the media subtype (pixel format)
    let mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription)
    let name = pixelFormatName(for: mediaSubType)
    return [PixelFormat(rawValue: mediaSubType, displayName: name)]
}

/// Human-readable name for a pixel format FourCC code.
private func pixelFormatName(for subType: FourCharCode) -> String {
    switch subType {
    case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        "420v (YUV Video Range)"
    case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
        "420f (YUV Full Range)"
    case kCVPixelFormatType_32BGRA:
        "BGRA 32-bit"
    case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
        "x420 (10-bit Video Range)"
    case kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
        "x420 (10-bit Full Range)"
    default:
        fourCCString(subType)
    }
}

/// Convert a FourCC code to a readable string.
private func fourCCString(_ code: FourCharCode) -> String {
    let bytes: [UInt8] = [
        UInt8((code >> 24) & 0xFF),
        UInt8((code >> 16) & 0xFF),
        UInt8((code >> 8) & 0xFF),
        UInt8(code & 0xFF),
    ]
    if let str = String(bytes: bytes, encoding: .ascii) {
        return str
    }
    return String(format: "0x%08X", code)
}

// MARK: - Stabilization Mode Discovery

/// Discover which stabilization modes a format supports.
/// This queries the actual format — never assumes any mode is available.
private func discoverStabilizationModes(from format: AVCaptureDevice.Format) -> [StabilizationMode] {
    var modes: [StabilizationMode] = [.off]  // .off is always available

    let candidates: [(AVCaptureVideoStabilizationMode, StabilizationMode)] = [
        (.standard, .standard),
        (.cinematic, .cinematic),
        (.cinematicExtended, .cinematicExtended),
        (.auto, .auto),
    ]

    for (avMode, domainMode) in candidates {
        if format.isVideoStabilizationModeSupported(avMode) {
            modes.append(domainMode)
        }
    }

    return modes
}

// MARK: - High Resolution Dimensions

/// Discover high-resolution still image dimensions if available.
private func discoverHighResDimensions(from format: AVCaptureDevice.Format) -> Resolution? {
    let dims = format.highResolutionStillImageDimensions
    guard dims.width > 0 && dims.height > 0 else { return nil }
    return Resolution(width: Int(dims.width), height: Int(dims.height))
}

// MARK: - Active Format Lookup

/// Find the `AVCaptureDevice.Format` that corresponds to a Domain `CaptureFormat`.
///
/// Matches by resolution and index encoded in the format ID.
func findAVFormat(
    matching domainFormat: CaptureFormat,
    in device: AVCaptureDevice
) -> AVCaptureDevice.Format? {
    // Parse index from format ID (e.g., "1920x1080_3" → index 3)
    guard let indexString = domainFormat.id.split(separator: "_").last,
          let index = Int(indexString),
          index >= 0 && index < device.formats.count else {
        return nil
    }

    let candidate = device.formats[index]
    let dims = CMVideoFormatDescriptionGetDimensions(candidate.formatDescription)

    // Verify resolution matches
    guard Int(dims.width) == domainFormat.resolution.width &&
          Int(dims.height) == domainFormat.resolution.height else {
        return nil
    }

    return candidate
}
