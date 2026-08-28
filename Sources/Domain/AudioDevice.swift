// AudioDevice.swift
// Domain — Value types representing audio input hardware, ports, and polar patterns.

import Foundation

// MARK: - Audio Port Type

/// High-level classification of audio input hardware connections.
public enum AudioPortType: String, Sendable, Codable, Hashable, CaseIterable {
    /// Built-in iOS microphone array.
    case builtInMic = "builtInMic"
    /// Wired headset microphone (3.5mm TRRS or Lightning/USB-C analog adapter).
    case headsetMic = "headsetMic"
    /// Dedicated line-in audio input interface.
    case lineIn = "lineIn"
    /// External USB audio interface, mixer, or USB microphone.
    case usbAudio = "usbAudio"
    /// Bluetooth Hands-Free Profile (bidirectional 16kHz or 8kHz SCO).
    case bluetoothHFP = "bluetoothHFP"
    /// Bluetooth Advanced Audio Distribution Profile (high quality input where supported).
    case bluetoothA2DP = "bluetoothA2DP"
    /// Bluetooth Low Energy audio endpoint.
    case bluetoothLE = "bluetoothLE"
    /// Other unclassified or virtual audio inputs.
    case other = "other"

    public var displayName: String {
        switch self {
        case .builtInMic: return "Built-In Microphone"
        case .headsetMic: return "Headset Microphone"
        case .lineIn: return "Line In"
        case .usbAudio: return "USB Audio Device"
        case .bluetoothHFP: return "Bluetooth Headset (HFP)"
        case .bluetoothA2DP: return "Bluetooth Audio (A2DP)"
        case .bluetoothLE: return "Bluetooth LE Audio"
        case .other: return "Other Audio Input"
        }
    }
}

// MARK: - Audio Polar Pattern

/// Microphone directional reception pattern.
public enum AudioPolarPattern: String, Sendable, Codable, Hashable, CaseIterable {
    case omnidirectional = "omnidirectional"
    case cardioid = "cardioid"
    case subcardioid = "subcardioid"
    case supercardioid = "supercardioid"
    case hypercardioid = "hypercardioid"
    case biDirectional = "biDirectional"
    case stereo = "stereo"
    case unspecified = "unspecified"

    public var displayName: String {
        switch self {
        case .omnidirectional: return "Omnidirectional"
        case .cardioid: return "Cardioid"
        case .subcardioid: return "Subcardioid"
        case .supercardioid: return "Supercardioid"
        case .hypercardioid: return "Hypercardioid"
        case .biDirectional: return "Bi-Directional"
        case .stereo: return "Stereo"
        case .unspecified: return "Default"
        }
    }
}

// MARK: - Audio Orientation

/// Physical direction or capsule placement for built-in microphones.
public enum AudioOrientation: String, Sendable, Codable, Hashable, CaseIterable {
    case top = "top"
    case bottom = "bottom"
    case front = "front"
    case back = "back"
    case left = "left"
    case right = "right"
    case unspecified = "unspecified"

    public var displayName: String {
        switch self {
        case .top: return "Top"
        case .bottom: return "Bottom"
        case .front: return "Front"
        case .back: return "Back"
        case .left: return "Left"
        case .right: return "Right"
        case .unspecified: return "Default Orientation"
        }
    }
}

// MARK: - Audio Data Source

/// A specific capsule, orientation, or polar pattern configuration exposed on a port.
public struct AudioDataSource: Sendable, Identifiable, Hashable, Codable {
    public let id: String
    public let name: String
    public let orientation: AudioOrientation
    public let polarPattern: AudioPolarPattern
    public let supportedPolarPatterns: [AudioPolarPattern]

    public init(
        id: String,
        name: String,
        orientation: AudioOrientation = .unspecified,
        polarPattern: AudioPolarPattern = .unspecified,
        supportedPolarPatterns: [AudioPolarPattern] = []
    ) {
        self.id = id
        self.name = name
        self.orientation = orientation
        self.polarPattern = polarPattern
        self.supportedPolarPatterns = supportedPolarPatterns
    }
}

// MARK: - Audio Input Device

/// Descriptor of an available audio input device discovered at runtime.
public struct AudioInputDevice: Sendable, Identifiable, Hashable, Codable {
    /// Unique identifier from the underlying AVAudioSession port description (UID).
    public let id: String
    /// Human-friendly port name (e.g., "iPhone Microphone", "RØDE Wireless PRO").
    public let name: String
    /// Connection type classification.
    public let portType: AudioPortType
    /// Number of hardware channels provided by this input port.
    public let channels: Int
    /// Available micro-capsule data sources (built-in microphone orientations / polar patterns).
    public let availableDataSources: [AudioDataSource]
    /// Currently selected data source if applicable.
    public let selectedDataSource: AudioDataSource?

    public init(
        id: String,
        name: String,
        portType: AudioPortType,
        channels: Int = 1,
        availableDataSources: [AudioDataSource] = [],
        selectedDataSource: AudioDataSource? = nil
    ) {
        self.id = id
        self.name = name
        self.portType = portType
        self.channels = max(channels, 1)
        self.availableDataSources = availableDataSources
        self.selectedDataSource = selectedDataSource
    }

    /// Whether this port is the built-in iOS microphone.
    public var isBuiltIn: Bool {
        portType == .builtInMic
    }

    /// Whether this port is an external USB audio input.
    public var isUSB: Bool {
        portType == .usbAudio
    }

    /// Whether this port connects over Bluetooth.
    public var isBluetooth: Bool {
        portType == .bluetoothHFP || portType == .bluetoothA2DP || portType == .bluetoothLE
    }
}
