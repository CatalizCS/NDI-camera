// NDITypesTests.swift
// DomainTests — Comprehensive unit tests for NDI domain types, configurations, tallies, and errors.

import Testing
import Foundation
@testable import Domain

// MARK: - NDIConfiguration Tests

@Suite("NDIConfiguration")
struct NDIConfigurationTests {

    @Test("default initialization sets sensible broadcast defaults")
    func defaultConfiguration() {
        let config = NDIConfiguration()
        #expect(config.sourceName == "TamaNDI-Camera")
        #expect(config.groups.isEmpty)
        #expect(config.targetResolution.width == 1920)
        #expect(config.targetResolution.height == 1080)
        #expect(config.targetFPS == 30.0)
        #expect(config.videoFormat == .bgra)
        #expect(config.audioSampleRate == 48000)
        #expect(config.audioChannelCount == 2)
        #expect(config.isClockVideo == true)
        #expect(config.isClockAudio == true)
    }

    @Test("NDIConfiguration round-trips through JSON")
    func configurationCodable() throws {
        let config = NDIConfiguration(
            sourceName: "Studio-Cam-A",
            groups: ["Production", "Stage"],
            targetResolution: Resolution(width: 3840, height: 2160),
            targetFPS: 60.0,
            videoFormat: .nv12,
            audioSampleRate: 44100,
            audioChannelCount: 1,
            isClockVideo: false,
            isClockAudio: false
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(NDIConfiguration.self, from: data)
        #expect(decoded == config)
    }
}

// MARK: - NDITally Tests

@Suite("NDITally")
struct NDITallyTests {

    @Test("static presets have correct flags")
    func tallyPresets() {
        let off = NDITally.off
        #expect(!off.inProgram && !off.inPreview)

        let program = NDITally.program
        #expect(program.inProgram && !program.inPreview)

        let preview = NDITally.preview
        #expect(!preview.inProgram && preview.inPreview)
    }

    @Test("NDITally round-trips through JSON")
    func tallyCodable() throws {
        let tally = NDITally(inProgram: true, inPreview: true)
        let data = try JSONEncoder().encode(tally)
        let decoded = try JSONDecoder().decode(NDITally.self, from: data)
        #expect(decoded == tally)
    }
}

// MARK: - NDIMetadata Tests

@Suite("NDIMetadata")
struct NDIMetadataTests {

    @Test("stores XML payload and optional timecode")
    func metadataPayload() {
        let xml = "<ndi_format><version>1.0</version></ndi_format>"
        let meta = NDIMetadata(payload: xml, timecodeMicros: 123456789)
        #expect(meta.payload == xml)
        #expect(meta.timecodeMicros == 123456789)
    }

    @Test("NDIMetadata round-trips through JSON")
    func metadataCodable() throws {
        let meta = NDIMetadata(payload: "<tally />", timecodeMicros: nil)
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(NDIMetadata.self, from: data)
        #expect(decoded == meta)
    }
}

// MARK: - NDIStats Tests

@Suite("NDIStats")
struct NDIStatsTests {

    @Test("default NDIStats has zeroed counters and off tally")
    func defaultStats() {
        let stats = NDIStats()
        #expect(stats.totalVideoFramesSent == 0)
        #expect(stats.totalVideoFramesDropped == 0)
        #expect(stats.totalAudioFramesSent == 0)
        #expect(stats.currentBitrateMbps == 0.0)
        #expect(stats.actualFPS == 0.0)
        #expect(stats.tally == .off)
        #expect(stats.connectedReceiversCount == 0)
    }

    @Test("NDIStats round-trips through JSON")
    func statsCodable() throws {
        let stats = NDIStats(
            totalVideoFramesSent: 1500,
            totalVideoFramesDropped: 2,
            totalAudioFramesSent: 3000,
            currentBitrateMbps: 125.4,
            actualFPS: 59.94,
            tally: .program,
            connectedReceiversCount: 3
        )
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(NDIStats.self, from: data)
        #expect(decoded == stats)
    }
}

// MARK: - NDIError Tests

@Suite("NDIError")
struct NDIErrorTests {

    @Test("All NDIError cases have non-empty localized error descriptions")
    func errorDescriptions() {
        let errors: [NDIError] = [
            .backendUnavailable(reason: "SDK framework not found in Vendor/NDI/"),
            .initializationFailed(reason: "NDIlib_initialize returned false"),
            .senderCreationFailed(reason: "Failed to allocate sender struct"),
            .senderNotFound(id: "sender-1"),
            .videoSendFailed(reason: "Output buffer pool exhausted"),
            .audioSendFailed(reason: "Unsupported audio channel layout"),
            .metadataSendFailed(reason: "Malformed XML string"),
            .queueOverflow(droppedFrames: 10),
            .invalidConfiguration(reason: "FPS must be greater than zero"),
            .notBroadcasting,
            .notInitialized
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("NDIError Hashable conformance")
    func errorHashable() {
        let e1 = NDIError.notBroadcasting
        let e2 = NDIError.notBroadcasting
        let e3 = NDIError.notInitialized

        #expect(e1 == e2)
        #expect(e1 != e3)
        let set: Set<NDIError> = [e1, e2, e3]
        #expect(set.count == 2)
    }
}
