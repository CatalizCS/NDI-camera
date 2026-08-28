// AudioRouteDiscoverer.swift
// Audio — Dynamic discovery and mapping of audio input routes, ports, capsules, and polar patterns.

import AVFoundation
import Domain

// MARK: - Audio Route Discoverer

/// Discovers connected audio input hardware and translates AVAudioSession port descriptions
/// and data sources into Domain models.
public final class AudioRouteDiscoverer: Sendable {

    public init() {}

    // MARK: - Device Discovery

    /// Discovers all currently available audio input devices from AVAudioSession.
    public func discoverAvailableInputs(session: AVAudioSession = .sharedInstance()) -> [AudioInputDevice] {
        let availableInputs = session.availableInputs ?? []
        let currentInputs = session.currentRoute.inputs

        return availableInputs.map { port in
            mapPortDescription(port, isSelected: currentInputs.contains { $0.uid == port.uid })
        }
    }

    /// Finds the currently active audio input device.
    public func currentInputDevice(session: AVAudioSession = .sharedInstance()) -> AudioInputDevice? {
        guard let currentPort = session.currentRoute.inputs.first else {
            return nil
        }
        return mapPortDescription(currentPort, isSelected: true)
    }

    // MARK: - Mappings

    /// Maps an AVAudioSessionPortDescription to an AudioInputDevice.
    public func mapPortDescription(
        _ port: AVAudioSessionPortDescription,
        isSelected: Bool = false
    ) -> AudioInputDevice {
        let portType = mapPortType(port.portType)
        let channelCount = port.channels?.count ?? 1

        let dataSources = (port.dataSources ?? []).map { mapDataSource($0) }

        var selectedDS: AudioDataSource?
        if let currentDS = port.selectedDataSource {
            selectedDS = mapDataSource(currentDS)
        } else if let firstDS = dataSources.first, portType == .builtInMic {
            selectedDS = firstDS
        }

        return AudioInputDevice(
            id: port.uid,
            name: port.portName,
            portType: portType,
            channels: max(channelCount, 1),
            availableDataSources: dataSources,
            selectedDataSource: selectedDS
        )
    }

    /// Maps AVAudioSession.Port to domain AudioPortType.
    public func mapPortType(_ port: AVAudioSession.Port) -> AudioPortType {
        switch port {
        case .builtInMic:
            return .builtInMic
        case .headsetMic:
            return .headsetMic
        case .lineIn:
            return .lineIn
        case .usbAudio:
            return .usbAudio
        case .bluetoothHFP:
            return .bluetoothHFP
        case .bluetoothA2DP:
            return .bluetoothA2DP
        case .bluetoothLE:
            return .bluetoothLE
        default:
            return .other
        }
    }

    /// Maps AVAudioSessionDataSourceDescription to domain AudioDataSource.
    public func mapDataSource(_ ds: AVAudioSessionDataSourceDescription) -> AudioDataSource {
        let orientation = mapOrientation(ds.orientation)
        let polarPattern = mapPolarPattern(ds.selectedPolarPattern)
        let supportedPatterns = (ds.supportedPolarPatterns ?? []).map { mapPolarPattern($0) }

        return AudioDataSource(
            id: "\(ds.dataSourceID)",
            name: ds.dataSourceName,
            orientation: orientation,
            polarPattern: polarPattern,
            supportedPolarPatterns: supportedPatterns
        )
    }

    /// Maps AVAudioSession.Orientation to domain AudioOrientation.
    public func mapOrientation(_ orientation: AVAudioSession.Orientation?) -> AudioOrientation {
        guard let orientation else { return .unspecified }
        switch orientation {
        case .top: return .top
        case .bottom: return .bottom
        case .front: return .front
        case .back: return .back
        case .left: return .left
        case .right: return .right
        default: return .unspecified
        }
    }

    /// Maps AVAudioSession.PolarPattern to domain AudioPolarPattern.
    public func mapPolarPattern(_ pattern: AVAudioSession.PolarPattern?) -> AudioPolarPattern {
        guard let pattern else { return .unspecified }
        switch pattern {
        case .omnidirectional: return .omnidirectional
        case .cardioid: return .cardioid
        case .subcardioid: return .subcardioid
        case .supercardioid: return .supercardioid
        case .hypercardioid: return .hypercardioid
        case .biDirectional: return .biDirectional
        case .stereo: return .stereo
        default: return .unspecified
        }
    }

    /// Maps domain AudioPolarPattern to AVAudioSession.PolarPattern.
    public func mapDomainPolarPattern(_ pattern: AudioPolarPattern) -> AVAudioSession.PolarPattern? {
        switch pattern {
        case .omnidirectional: return .omnidirectional
        case .cardioid: return .cardioid
        case .subcardioid: return .subcardioid
        case .supercardioid: return .supercardioid
        case .hypercardioid: return .hypercardioid
        case .biDirectional: return .biDirectional
        case .stereo: return .stereo
        case .unspecified: return nil
        }
    }
}
