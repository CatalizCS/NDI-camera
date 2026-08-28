// AudioRouteDiscovererTests.swift
// AudioTests — Unit tests for port type classification, orientations, and polar pattern mappings.

import Testing
import Foundation
import AVFoundation
@testable import Audio
@testable import Domain

@Suite("AudioRouteDiscoverer Tests")
struct AudioRouteDiscovererTests {

    @Test("Port type mapping correctly identifies all supported port types")
    func mapPortType() {
        let discoverer = AudioRouteDiscoverer()

        #expect(discoverer.mapPortType(.builtInMic) == .builtInMic)
        #expect(discoverer.mapPortType(.headsetMic) == .headsetMic)
        #expect(discoverer.mapPortType(.lineIn) == .lineIn)
        #expect(discoverer.mapPortType(.usbAudio) == .usbAudio)
        #expect(discoverer.mapPortType(.bluetoothHFP) == .bluetoothHFP)
        #expect(discoverer.mapPortType(.bluetoothA2DP) == .bluetoothA2DP)
        #expect(discoverer.mapPortType(.bluetoothLE) == .bluetoothLE)
        #expect(discoverer.mapPortType(.airPlay) == .other)
    }

    @Test("Orientation mapping handles all directions")
    func mapOrientation() {
        let discoverer = AudioRouteDiscoverer()

        #expect(discoverer.mapOrientation(.top) == .top)
        #expect(discoverer.mapOrientation(.bottom) == .bottom)
        #expect(discoverer.mapOrientation(.front) == .front)
        #expect(discoverer.mapOrientation(.back) == .back)
        #expect(discoverer.mapOrientation(.left) == .left)
        #expect(discoverer.mapOrientation(.right) == .right)
        #expect(discoverer.mapOrientation(nil) == .unspecified)
    }

    @Test("Polar pattern mapping is bidirectional")
    func mapPolarPattern() {
        let discoverer = AudioRouteDiscoverer()

        #expect(discoverer.mapPolarPattern(.omnidirectional) == .omnidirectional)
        #expect(discoverer.mapPolarPattern(.cardioid) == .cardioid)
        #expect(discoverer.mapPolarPattern(.subcardioid) == .subcardioid)
        #expect(discoverer.mapPolarPattern(.supercardioid) == .supercardioid)
        #expect(discoverer.mapPolarPattern(.hypercardioid) == .hypercardioid)
        #expect(discoverer.mapPolarPattern(.biDirectional) == .biDirectional)
        #expect(discoverer.mapPolarPattern(.stereo) == .stereo)
        #expect(discoverer.mapPolarPattern(nil) == .unspecified)

        #expect(discoverer.mapDomainPolarPattern(.cardioid) == .cardioid)
        #expect(discoverer.mapDomainPolarPattern(.omnidirectional) == .omnidirectional)
        #expect(discoverer.mapDomainPolarPattern(.stereo) == .stereo)
        #expect(discoverer.mapDomainPolarPattern(.unspecified) == nil)
    }
}
