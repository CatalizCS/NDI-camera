// MultiCamTypes.swift
// Domain — Shared MultiCam types, configurations, and composite layout descriptors.
// Pure Swift value types without AVFoundation dependency.

import Foundation

// MARK: - MultiCam Slot

/// Identifies the role of a physical camera in a multi-camera session.
public enum MultiCamSlot: String, Sendable, Codable, CaseIterable, Hashable, Identifiable, CustomStringConvertible {
    case primary
    case secondary
    case tertiary

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .primary: "Primary Camera"
        case .secondary: "Secondary Camera"
        case .tertiary: "Tertiary Camera"
        }
    }

    /// Display order index (0 = primary, 1 = secondary, 2 = tertiary).
    public var index: Int {
        switch self {
        case .primary: 0
        case .secondary: 1
        case .tertiary: 2
        }
    }
}

// MARK: - Picture-in-Picture Position

/// Screen corner position for PiP inset rendering.
public enum PiPPosition: String, Sendable, Codable, CaseIterable, Hashable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    /// Human-readable label for UI.
    public var displayName: String {
        switch self {
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        }
    }
}

// MARK: - Normalized Rect

/// A rectangle in normalized coordinates (0.0 ... 1.0) for composition viewports.
/// Origin (x, y) is top-left, with positive x extending right and positive y extending down.
public struct NormalizedRect: Sendable, Hashable, Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = min(max(x, 0.0), 1.0)
        self.y = min(max(y, 0.0), 1.0)
        self.width = min(max(width, 0.0), 1.0 - self.x)
        self.height = min(max(height, 0.0), 1.0 - self.y)
    }

    /// Full frame (0, 0, 1, 1).
    public static let full = NormalizedRect(x: 0, y: 0, width: 1, height: 1)
}

// MARK: - Composite Layout

/// Visual layout configuration for multi-camera composition.
public enum CompositeLayout: Sendable, Codable, Hashable {
    /// Primary camera full-screen with secondary camera as a corner PiP inset.
    /// `sizeFraction` represents the width of the inset relative to output width (e.g. 0.25 to 0.50, default 0.30).
    case pictureInPicture(position: PiPPosition, sizeFraction: Double)

    /// Side-by-side split layout (2 cameras).
    /// `splitRatio` is the boundary fraction (0.1 ... 0.9, default 0.5).
    case sideBySide(splitRatio: Double, isVertical: Bool)

    /// Primary full background with dual corner PiP insets for secondary and tertiary cameras.
    case primaryWithDualInsets(secondaryPosition: PiPPosition, tertiaryPosition: PiPPosition, sizeFraction: Double)

    /// Three cameras arranged in a grid: 1 primary on top (or bottom) + 2 side-by-side below.
    case threeGrid(primaryOnTop: Bool)

    /// Three cameras arranged in equal vertical columns (horizontal split).
    case threeSplitHorizontal

    /// Three cameras arranged in equal horizontal rows (vertical split).
    case threeSplitVertical

    // MARK: - Viewport Calculations

    /// Computes the normalized viewport rectangles for each active slot in this layout.
    public func viewports(for slots: [MultiCamSlot]) -> [MultiCamSlot: NormalizedRect] {
        var rects: [MultiCamSlot: NormalizedRect] = [:]
        let margin = 0.02 // 2% margin from edges for PiP

        switch self {
        case .pictureInPicture(let position, let sizeFraction):
            let pipW = min(max(sizeFraction, 0.15), 0.60)
            let pipH = pipW * (9.0 / 16.0) // 16:9 aspect match

            rects[.primary] = .full

            if slots.contains(.secondary) {
                let pipX: Double
                let pipY: Double
                switch position {
                case .topLeft:
                    pipX = margin
                    pipY = margin
                case .topRight:
                    pipX = 1.0 - pipW - margin
                    pipY = margin
                case .bottomLeft:
                    pipX = margin
                    pipY = 1.0 - pipH - margin
                case .bottomRight:
                    pipX = 1.0 - pipW - margin
                    pipY = 1.0 - pipH - margin
                }
                rects[.secondary] = NormalizedRect(x: pipX, y: pipY, width: pipW, height: pipH)
            }

        case .sideBySide(let splitRatio, let isVertical):
            let ratio = min(max(splitRatio, 0.1), 0.9)
            if isVertical {
                // Top / Bottom
                rects[.primary] = NormalizedRect(x: 0, y: 0, width: 1, height: ratio)
                if slots.contains(.secondary) {
                    rects[.secondary] = NormalizedRect(x: 0, y: ratio, width: 1, height: 1.0 - ratio)
                }
            } else {
                // Left / Right
                rects[.primary] = NormalizedRect(x: 0, y: 0, width: ratio, height: 1)
                if slots.contains(.secondary) {
                    rects[.secondary] = NormalizedRect(x: ratio, y: 0, width: 1.0 - ratio, height: 1)
                }
            }

        case .primaryWithDualInsets(let secPos, let tertPos, let sizeFraction):
            let pipW = min(max(sizeFraction, 0.15), 0.40)
            let pipH = pipW * (9.0 / 16.0)
            rects[.primary] = .full

            func computePipRect(_ pos: PiPPosition) -> NormalizedRect {
                let px: Double
                let py: Double
                switch pos {
                case .topLeft:
                    px = margin; py = margin
                case .topRight:
                    px = 1.0 - pipW - margin; py = margin
                case .bottomLeft:
                    px = margin; py = 1.0 - pipH - margin
                case .bottomRight:
                    px = 1.0 - pipW - margin; py = 1.0 - pipH - margin
                }
                return NormalizedRect(x: px, y: py, width: pipW, height: pipH)
            }

            if slots.contains(.secondary) {
                rects[.secondary] = computePipRect(secPos)
            }
            if slots.contains(.tertiary) {
                rects[.tertiary] = computePipRect(tertPos)
            }

        case .threeGrid(let primaryOnTop):
            if primaryOnTop {
                rects[.primary] = NormalizedRect(x: 0, y: 0, width: 1.0, height: 0.5)
                if slots.contains(.secondary) {
                    rects[.secondary] = NormalizedRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
                }
                if slots.contains(.tertiary) {
                    rects[.tertiary] = NormalizedRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
                }
            } else {
                if slots.contains(.secondary) {
                    rects[.secondary] = NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5)
                }
                if slots.contains(.tertiary) {
                    rects[.tertiary] = NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
                }
                rects[.primary] = NormalizedRect(x: 0, y: 0.5, width: 1.0, height: 0.5)
            }

        case .threeSplitHorizontal:
            rects[.primary] = NormalizedRect(x: 0, y: 0, width: 1.0 / 3.0, height: 1.0)
            if slots.contains(.secondary) {
                rects[.secondary] = NormalizedRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1.0)
            }
            if slots.contains(.tertiary) {
                rects[.tertiary] = NormalizedRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1.0)
            }

        case .threeSplitVertical:
            rects[.primary] = NormalizedRect(x: 0, y: 0, width: 1.0, height: 1.0 / 3.0)
            if slots.contains(.secondary) {
                rects[.secondary] = NormalizedRect(x: 0, y: 1.0 / 3.0, width: 1.0, height: 1.0 / 3.0)
            }
            if slots.contains(.tertiary) {
                rects[.tertiary] = NormalizedRect(x: 0, y: 2.0 / 3.0, width: 1.0, height: 1.0 / 3.0)
            }
        }

        return rects
    }
}

// MARK: - MultiCam Device Combination

/// Represents a validated set of physical camera devices that can operate simultaneously.
public struct MultiCamDeviceCombination: Sendable, Hashable, Identifiable, Codable {
    public var id: String {
        devices.map(\.id).sorted().joined(separator: "+")
    }

    /// The list of camera devices in this combination.
    public let devices: [CameraDevice]

    /// Estimated aggregate hardware cost score (0.0 to 1.0). Must not exceed 1.0.
    public let totalHardwareCost: Float

    /// Resolutions supported simultaneously by all devices in this combination.
    public let supportedResolutions: [Resolution]

    /// Maximum frame rate supported simultaneously across all devices.
    public let maxSupportedFPS: Double

    public init(
        devices: [CameraDevice],
        totalHardwareCost: Float,
        supportedResolutions: [Resolution],
        maxSupportedFPS: Double
    ) {
        self.devices = devices
        self.totalHardwareCost = totalHardwareCost
        self.supportedResolutions = supportedResolutions
        self.maxSupportedFPS = maxSupportedFPS
    }
}

// MARK: - MultiCam Configuration

/// Active configuration descriptor for a multi-camera capture session.
public struct MultiCamConfiguration: Sendable, Hashable {
    public let mode: CameraMode
    public let slots: [MultiCamSlot: CameraDevice]
    public let formats: [MultiCamSlot: CaptureFormat]
    public let layout: CompositeLayout?
    public let targetFPS: Double

    public init(
        mode: CameraMode,
        slots: [MultiCamSlot: CameraDevice] = [:],
        formats: [MultiCamSlot: CaptureFormat] = [:],
        layout: CompositeLayout? = nil,
        targetFPS: Double = 30.0
    ) {
        self.mode = mode
        self.slots = slots
        self.formats = formats
        self.layout = layout
        self.targetFPS = targetFPS
    }
}

// MARK: - MultiCam State

/// Complete observable state snapshot of the MultiCam engine.
public struct MultiCamState: Sendable, Hashable {
    public let mode: CameraMode
    public let activeSlots: [MultiCamSlot: CameraDevice]
    public let activeFormats: [MultiCamSlot: CaptureFormat]
    public let layout: CompositeLayout?
    public let targetFPS: Double
    public let sessionState: StreamState
    public let hardwareCost: Float

    public init(
        mode: CameraMode = .single,
        activeSlots: [MultiCamSlot: CameraDevice] = [:],
        activeFormats: [MultiCamSlot: CaptureFormat] = [:],
        layout: CompositeLayout? = nil,
        targetFPS: Double = 30.0,
        sessionState: StreamState = .idle,
        hardwareCost: Float = 0.0
    ) {
        self.mode = mode
        self.activeSlots = activeSlots
        self.activeFormats = activeFormats
        self.layout = layout
        self.targetFPS = targetFPS
        self.sessionState = sessionState
        self.hardwareCost = hardwareCost
    }
}
