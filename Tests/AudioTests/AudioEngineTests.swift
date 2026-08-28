// AudioEngineTests.swift
// AudioTests — Unit tests for AudioEngine actor state management, controls, and protocols.

import Testing
import Foundation
import AVFoundation
@testable import Audio
@testable import Domain

@Suite("AudioEngine Tests")
struct AudioEngineTests {

    @Test("AudioEngine initializes with sensible broadcast defaults")
    func engineInitialDefaults() async {
        let engine = AudioEngine()
        let state = await engine.currentState()

        #expect(state.isRunning == false)
        #expect(state.isMuted == false)
        #expect(state.gain == 1.0)
        #expect(state.sampleRate == .rate48000)
        #expect(state.channelLayout == .stereo)
        #expect(state.sessionState == .idle)
    }

    @Test("AudioEngine updates gain and mute state properly")
    func gainAndMuteUpdates() async throws {
        let engine = AudioEngine()

        await engine.setMuted(true)
        var state = await engine.currentState()
        #expect(state.isMuted == true)

        await engine.setMuted(false)
        state = await engine.currentState()
        #expect(state.isMuted == false)

        try await engine.setGain(1.5)
        state = await engine.currentState()
        #expect(state.gain == 1.5)

        try await engine.setGain(0.0)
        state = await engine.currentState()
        #expect(state.gain == 0.0)
    }

    @Test("AudioEngine updates sample rate and channel layout")
    func formatUpdates() async throws {
        let engine = AudioEngine()

        try await engine.setSampleRate(.rate44100)
        var state = await engine.currentState()
        #expect(state.sampleRate == .rate44100)

        try await engine.setChannelLayout(.mono)
        state = await engine.currentState()
        #expect(state.channelLayout == .mono)
    }

    @Test("AudioEngine provides dynamic capability listings")
    func capabilityQueries() async {
        let engine = AudioEngine()
        let dummyDevice = AudioInputDevice(
            id: "dummy-id",
            name: "Test Mic",
            portType: .usbAudio,
            channels: 2
        )

        let rates = await engine.supportedSampleRates(for: dummyDevice)
        #expect(rates.contains(.rate48000))
        #expect(rates.contains(.rate44100))

        let channels = await engine.supportedChannelCounts(for: dummyDevice)
        #expect(channels.contains(1))
        #expect(channels.contains(2))

        let levels = await engine.currentLevels()
        #expect(levels.peakLevels.count >= 2)
    }
}
