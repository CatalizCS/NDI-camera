// AudioTypesTests.swift
// DomainTests — Comprehensive unit tests for Audio domain types, formats, ports, and errors.

import Testing
import Foundation
@testable import Domain

// MARK: - AudioDevice & Port Tests

@Suite("AudioDevice & Port Tests")
struct AudioDeviceTests {

    @Test("AudioPortType classification and display names")
    func portTypes() {
        #expect(AudioPortType.builtInMic.displayName == "Built-In Microphone")
        #expect(AudioPortType.usbAudio.displayName == "USB Audio Device")
        #expect(AudioPortType.bluetoothHFP.displayName == "Bluetooth Headset (HFP)")
        #expect(AudioPortType.bluetoothA2DP.displayName == "Bluetooth Audio (A2DP)")
        #expect(AudioPortType.bluetoothLE.displayName == "Bluetooth LE Audio")
        #expect(AudioPortType.headsetMic.displayName == "Headset Microphone")
        #expect(AudioPortType.lineIn.displayName == "Line In")
        #expect(AudioPortType.other.displayName == "Other Audio Input")
    }

    @Test("AudioInputDevice properties and helper flags")
    func inputDeviceFlags() {
        let builtIn = AudioInputDevice(
            id: "builtin-mic-uid",
            name: "iPhone Microphone",
            portType: .builtInMic,
            channels: 2
        )
        #expect(builtIn.isBuiltIn == true)
        #expect(builtIn.isUSB == false)
        #expect(builtIn.isBluetooth == false)
        #expect(builtIn.channels == 2)

        let usbMic = AudioInputDevice(
            id: "usb-mic-uid",
            name: "RØDE NT-USB Mini",
            portType: .usbAudio,
            channels: 1
        )
        #expect(usbMic.isBuiltIn == false)
        #expect(usbMic.isUSB == true)
        #expect(usbMic.isBluetooth == false)

        let btMic = AudioInputDevice(
            id: "bt-mic-uid",
            name: "AirPods Pro",
            portType: .bluetoothHFP,
            channels: 1
        )
        #expect(btMic.isBuiltIn == false)
        #expect(btMic.isUSB == false)
        #expect(btMic.isBluetooth == true)
    }

    @Test("AudioInputDevice round-trips through JSON")
    func deviceCodable() throws {
        let ds = AudioDataSource(
            id: "front-capsule",
            name: "Front Microphone",
            orientation: .front,
            polarPattern: .cardioid,
            supportedPolarPatterns: [.cardioid, .omnidirectional]
        )
        let device = AudioInputDevice(
            id: "uid-12345",
            name: "Studio Mic",
            portType: .usbAudio,
            channels: 2,
            availableDataSources: [ds],
            selectedDataSource: ds
        )

        let data = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(AudioInputDevice.self, from: data)
        #expect(decoded == device)
        #expect(decoded.selectedDataSource?.polarPattern == .cardioid)
    }
}

// MARK: - AudioFormat Tests

@Suite("AudioFormat & Configuration Tests")
struct AudioFormatTests {

    @Test("AudioSampleRate nearest matching")
    func nearestSampleRate() {
        #expect(AudioSampleRate.nearest(to: 48000) == .rate48000)
        #expect(AudioSampleRate.nearest(to: 47999.5) == .rate48000)
        #expect(AudioSampleRate.nearest(to: 44100) == .rate44100)
        #expect(AudioSampleRate.nearest(to: 96000) == .rate96000)
    }

    @Test("AudioChannelLayout conversions")
    func channelLayouts() {
        #expect(AudioChannelLayout.from(channelCount: 1) == .mono)
        #expect(AudioChannelLayout.from(channelCount: 2) == .stereo)
        #expect(AudioChannelLayout.from(channelCount: 4) == .multiChannel)

        #expect(AudioChannelLayout.mono.channelCount == 1)
        #expect(AudioChannelLayout.stereo.channelCount == 2)
        #expect(AudioChannelLayout.multiChannel.channelCount == 4)
    }

    @Test("AudioConfiguration defaults and round-trip")
    func audioConfiguration() throws {
        let config = AudioConfiguration()
        #expect(config.sampleRate == .rate48000)
        #expect(config.channelLayout == .stereo)
        #expect(config.bufferDuration == 0.01)
        #expect(config.allowBluetooth == true)

        let custom = AudioConfiguration(
            sampleRate: .rate44100,
            channelLayout: .mono,
            bufferDuration: 0.005,
            allowBluetooth: false
        )
        let data = try JSONEncoder().encode(custom)
        let decoded = try JSONDecoder().decode(AudioConfiguration.self, from: data)
        #expect(decoded == custom)
    }
}

// MARK: - AudioLevels Tests

@Suite("AudioLevels Tests")
struct AudioLevelsTests {

    @Test("AudioLevelsSnapshot defaults and silence constant")
    func levelsSnapshot() {
        let silence = AudioLevelsSnapshot.silence
        #expect(silence.peakLevels == [-160.0, -160.0])
        #expect(silence.rmsLevels == [-160.0, -160.0])
        #expect(silence.isClipping == false)

        let active = AudioLevelsSnapshot(
            peakLevels: [-6.0, -5.5],
            rmsLevels: [-18.0, -17.5],
            isClipping: false
        )
        #expect(active.peakLevels.count == 2)
        #expect(active.isClipping == false)
    }
}

// MARK: - AudioError Tests

@Suite("AudioError Tests")
struct AudioErrorTests {

    @Test("All AudioError cases have non-empty localized descriptions")
    func audioErrors() {
        let errors: [AudioError] = [
            .permissionDenied,
            .deviceNotFound(deviceID: "mic-1"),
            .sessionActivationFailed(reason: "Resource unavailable"),
            .categoryConfigurationFailed(reason: "Unsupported category"),
            .portSelectionFailed(reason: "Port not present"),
            .dataSourceSelectionFailed(reason: "Invalid capsule"),
            .unsupportedSampleRate(requested: 192000),
            .unsupportedChannelCount(requested: 8),
            .gainNotSupported,
            .engineStartFailed(reason: "Engine failed to start"),
            .conversionFailed(reason: "ASBD mismatch"),
            .notRunning,
            .alreadyRunning
        ]

        for err in errors {
            #expect(err.errorDescription != nil)
            #expect(!err.errorDescription!.isEmpty)
        }
    }

    @Test("AudioError Hashable conformance")
    func errorHashable() {
        let e1 = AudioError.permissionDenied
        let e2 = AudioError.permissionDenied
        let e3 = AudioError.notRunning

        #expect(e1 == e2)
        #expect(e1 != e3)

        let set: Set<AudioError> = [e1, e2, e3]
        #expect(set.count == 2)
    }
}
