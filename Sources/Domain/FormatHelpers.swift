// FormatHelpers.swift
// Domain — Pure functions for filtering, sorting, and selecting capture formats.
//
// These functions operate only on Domain value types (CaptureFormat, Resolution, FPSRange).
// They have no AVFoundation dependency and are fully unit-testable on any platform.

import Foundation

// MARK: - Format Filtering

/// Filter formats that match an exact resolution.
public func formats(
    matching resolution: Resolution,
    from formats: [CaptureFormat]
) -> [CaptureFormat] {
    formats.filter { $0.resolution == resolution }
}

/// Filter formats that support a specific frame rate.
public func formats(
    supportingFPS fps: Double,
    from formats: [CaptureFormat]
) -> [CaptureFormat] {
    formats.filter { $0.supports(fps: fps) }
}

/// Filter formats that support at least the specified resolution.
public func formats(
    atLeast minResolution: Resolution,
    from formats: [CaptureFormat]
) -> [CaptureFormat] {
    formats.filter { $0.resolution >= minResolution }
}

/// Filter formats that support multi-camera sessions.
public func multiCamFormats(from formats: [CaptureFormat]) -> [CaptureFormat] {
    formats.filter(\.isMultiCamSupported)
}

/// Filter formats that are not binned (full-quality).
public func nonBinnedFormats(from formats: [CaptureFormat]) -> [CaptureFormat] {
    formats.filter { !$0.isVideoBinned }
}

/// Filter formats that support a specific stabilization mode.
public func formats(
    supportingStabilization mode: StabilizationMode,
    from formats: [CaptureFormat]
) -> [CaptureFormat] {
    formats.filter { $0.supportedStabilizationModes.contains(mode) }
}

// MARK: - Resolution Extraction

/// Extract unique resolutions from a list of formats, sorted by pixel count descending.
public func uniqueResolutions(from formats: [CaptureFormat]) -> [Resolution] {
    let unique = Set(formats.map(\.resolution))
    return unique.sorted(by: >)
}

// MARK: - FPS Extraction

/// Extract unique max frame rates available for a specific resolution.
/// Returns sorted ascending.
public func availableFPS(
    for resolution: Resolution,
    from formats: [CaptureFormat]
) -> [Double] {
    let matching = formats.filter { $0.resolution == resolution }
    let allFPS = Set(matching.flatMap { format in
        format.fpsRanges.map(\.maxFrameRate)
    })
    return allFPS.sorted()
}

/// Extract all unique max frame rates across all formats, sorted ascending.
public func allAvailableFPS(from formats: [CaptureFormat]) -> [Double] {
    let allFPS = Set(formats.flatMap { format in
        format.fpsRanges.map(\.maxFrameRate)
    })
    return allFPS.sorted()
}

// MARK: - Format Sorting

/// Sort formats by quality preference:
/// 1. Higher resolution first
/// 2. Non-binned preferred over binned
/// 3. Higher max FPS first
/// 4. Wider field of view first
public func sortedByQuality(_ formats: [CaptureFormat]) -> [CaptureFormat] {
    formats.sorted { lhs, rhs in
        // Primary: resolution (higher pixel count first)
        if lhs.resolution.pixelCount != rhs.resolution.pixelCount {
            return lhs.resolution.pixelCount > rhs.resolution.pixelCount
        }
        // Secondary: prefer non-binned
        if lhs.isVideoBinned != rhs.isVideoBinned {
            return !lhs.isVideoBinned
        }
        // Tertiary: higher max FPS
        if lhs.maxFrameRate != rhs.maxFrameRate {
            return lhs.maxFrameRate > rhs.maxFrameRate
        }
        // Quaternary: wider field of view
        return lhs.videoFieldOfView > rhs.videoFieldOfView
    }
}

// MARK: - Best Format Selection

/// Find the best format matching the given constraints.
///
/// Selection strategy:
/// 1. Filter to formats matching the preferred resolution
/// 2. Among those, filter to formats supporting the preferred FPS
/// 3. Prefer non-binned formats
/// 4. If no exact match, find the closest resolution that supports the FPS
/// 5. Returns `nil` if no viable format exists
public func bestFormat(
    width: Int,
    height: Int,
    fps: Double,
    from formats: [CaptureFormat]
) -> CaptureFormat? {
    let targetResolution = Resolution(width: width, height: height)

    // Try exact resolution + FPS match
    let exactMatches = formats.filter {
        $0.resolution == targetResolution && $0.supports(fps: fps)
    }
    if let best = preferNonBinned(exactMatches) {
        return best
    }

    // Try exact resolution, any FPS
    let resolutionMatches = formats.filter { $0.resolution == targetResolution }
    if let best = preferNonBinned(resolutionMatches) {
        return best
    }

    // Fall back to closest resolution that supports the FPS
    let fpsMatches = formats.filter { $0.supports(fps: fps) }
    let closest = fpsMatches.min(by: { lhs, rhs in
        abs(lhs.resolution.pixelCount - targetResolution.pixelCount) <
            abs(rhs.resolution.pixelCount - targetResolution.pixelCount)
    })
    if let closest {
        return closest
    }

    // Last resort: any format closest to target resolution
    return formats.min(by: { lhs, rhs in
        abs(lhs.resolution.pixelCount - targetResolution.pixelCount) <
            abs(rhs.resolution.pixelCount - targetResolution.pixelCount)
    })
}

/// From a list of candidates, prefer the non-binned format with the highest max FPS.
private func preferNonBinned(_ candidates: [CaptureFormat]) -> CaptureFormat? {
    let nonBinned = candidates.filter { !$0.isVideoBinned }
    if let best = nonBinned.max(by: { $0.maxFrameRate < $1.maxFrameRate }) {
        return best
    }
    return candidates.max(by: { $0.maxFrameRate < $1.maxFrameRate })
}

// MARK: - Format Validation

/// Validate that a format supports a given FPS and stabilization combination.
public func isValidCombination(
    format: CaptureFormat,
    fps: Double,
    stabilization: StabilizationMode
) -> Bool {
    let supportsFPS = format.supports(fps: fps)
    let supportsStabilization = stabilization == .off ||
        format.supportedStabilizationModes.contains(stabilization)
    return supportsFPS && supportsStabilization
}

/// Find formats that support both the specified FPS and stabilization mode.
public func formats(
    supportingFPS fps: Double,
    andStabilization stabilization: StabilizationMode,
    from formats: [CaptureFormat]
) -> [CaptureFormat] {
    formats.filter { isValidCombination(format: $0, fps: fps, stabilization: stabilization) }
}
