// MultiCamTypesTests.swift
// DomainTests — Comprehensive unit tests for MultiCam domain types, layout geometry, and errors.

import Testing
import Foundation
@testable import Domain

// MARK: - MultiCamSlot Tests

@Suite("MultiCamSlot")
struct MultiCamSlotTests {

    @Test("allCases contains primary, secondary, tertiary in expected order")
    func allCasesOrder() {
        let cases = MultiCamSlot.allCases
        #expect(cases.count == 3)
        #expect(cases[0] == .primary)
        #expect(cases[1] == .secondary)
        #expect(cases[2] == .tertiary)
    }

    @Test("slot index and id match expectations")
    func slotProperties() {
        #expect(MultiCamSlot.primary.index == 0)
        #expect(MultiCamSlot.secondary.index == 1)
        #expect(MultiCamSlot.tertiary.index == 2)

        #expect(MultiCamSlot.primary.id == "primary")
        #expect(MultiCamSlot.secondary.id == "secondary")
        #expect(MultiCamSlot.tertiary.id == "tertiary")
    }

    @Test("descriptions are human readable")
    func slotDescriptions() {
        #expect(MultiCamSlot.primary.description.contains("Primary"))
        #expect(MultiCamSlot.secondary.description.contains("Secondary"))
        #expect(MultiCamSlot.tertiary.description.contains("Tertiary"))
    }
}

// MARK: - NormalizedRect Tests

@Suite("NormalizedRect")
struct NormalizedRectTests {

    @Test("full rect covers 0.0 to 1.0")
    func fullRect() {
        let full = NormalizedRect.full
        #expect(full.x == 0.0)
        #expect(full.y == 0.0)
        #expect(full.width == 1.0)
        #expect(full.height == 1.0)
    }

    @Test("clamps out of bounds coordinates")
    func clampingCoordinates() {
        let r = NormalizedRect(x: -0.5, y: 1.5, width: 2.0, height: 2.0)
        #expect(r.x == 0.0)
        #expect(r.y == 1.0)
        #expect(r.width == 1.0)
        #expect(r.height == 0.0) // clamped because 1.0 - y = 0.0
    }
}

// MARK: - CompositeLayout Geometry Tests

@Suite("CompositeLayout")
struct CompositeLayoutTests {

    @Test("Picture-in-Picture top-right viewport geometry")
    func pipTopRight() {
        let layout = CompositeLayout.pictureInPicture(position: .topRight, sizeFraction: 0.30)
        let viewports = layout.viewports(for: [.primary, .secondary])

        #expect(viewports[.primary] == .full)
        let sec = viewports[.secondary]
        #expect(sec != nil)
        #expect(sec!.width == 0.30)
        #expect(sec!.x > 0.6) // positioned to the right
        #expect(sec!.y < 0.1) // positioned at the top
    }

    @Test("Picture-in-Picture bottom-left viewport geometry")
    func pipBottomLeft() {
        let layout = CompositeLayout.pictureInPicture(position: .bottomLeft, sizeFraction: 0.25)
        let viewports = layout.viewports(for: [.primary, .secondary])

        let sec = viewports[.secondary]
        #expect(sec != nil)
        #expect(sec!.width == 0.25)
        #expect(sec!.x < 0.1) // positioned to the left
        #expect(sec!.y > 0.7) // positioned at the bottom
    }

    @Test("Side-by-Side horizontal split (left / right)")
    func sideBySideHorizontal() {
        let layout = CompositeLayout.sideBySide(splitRatio: 0.5, isVertical: false)
        let viewports = layout.viewports(for: [.primary, .secondary])

        let prim = viewports[.primary]
        let sec = viewports[.secondary]

        #expect(prim != nil && sec != nil)
        #expect(prim!.x == 0.0)
        #expect(prim!.width == 0.5)
        #expect(prim!.height == 1.0)

        #expect(sec!.x == 0.5)
        #expect(sec!.width == 0.5)
        #expect(sec!.height == 1.0)
    }

    @Test("Side-by-Side vertical split (top / bottom)")
    func sideBySideVertical() {
        let layout = CompositeLayout.sideBySide(splitRatio: 0.6, isVertical: true)
        let viewports = layout.viewports(for: [.primary, .secondary])

        let prim = viewports[.primary]
        let sec = viewports[.secondary]

        #expect(prim != nil && sec != nil)
        #expect(prim!.y == 0.0)
        #expect(prim!.height == 0.6)
        #expect(prim!.width == 1.0)

        #expect(sec!.y == 0.6)
        #expect(sec!.height == 0.4)
        #expect(sec!.width == 1.0)
    }

    @Test("Three Grid layout viewports")
    func threeGridLayout() {
        let layout = CompositeLayout.threeGrid(primaryOnTop: true)
        let viewports = layout.viewports(for: [.primary, .secondary, .tertiary])

        let prim = viewports[.primary]
        let sec = viewports[.secondary]
        let tert = viewports[.tertiary]

        #expect(prim != nil && sec != nil && tert != nil)
        #expect(prim!.x == 0.0 && prim!.y == 0.0 && prim!.width == 1.0 && prim!.height == 0.5)
        #expect(sec!.x == 0.0 && sec!.y == 0.5 && sec!.width == 0.5 && sec!.height == 0.5)
        #expect(tert!.x == 0.5 && tert!.y == 0.5 && tert!.width == 0.5 && tert!.height == 0.5)
    }

    @Test("Three Split Horizontal layout viewports")
    func threeSplitHorizontalLayout() {
        let layout = CompositeLayout.threeSplitHorizontal
        let viewports = layout.viewports(for: [.primary, .secondary, .tertiary])

        let prim = viewports[.primary]
        let sec = viewports[.secondary]
        let tert = viewports[.tertiary]

        #expect(prim != nil && sec != nil && tert != nil)
        #expect(abs(prim!.width - 1.0/3.0) < 0.001)
        #expect(abs(sec!.width - 1.0/3.0) < 0.001)
        #expect(abs(tert!.width - 1.0/3.0) < 0.001)
    }
}

// MARK: - Model Codable & Hashable Tests

@Suite("MultiCam Models")
struct MultiCamModelsTests {

    @Test("MultiCamSlot round-trips JSON")
    func slotCodable() throws {
        for slot in MultiCamSlot.allCases {
            let data = try JSONEncoder().encode(slot)
            let decoded = try JSONDecoder().decode(MultiCamSlot.self, from: data)
            #expect(decoded == slot)
        }
    }

    @Test("PiPPosition round-trips JSON")
    func pipPositionCodable() throws {
        for pos in PiPPosition.allCases {
            let data = try JSONEncoder().encode(pos)
            let decoded = try JSONDecoder().decode(PiPPosition.self, from: data)
            #expect(decoded == pos)
            #expect(!pos.displayName.isEmpty)
        }
    }

    @Test("MultiCamDeviceCombination codable and id")
    func deviceCombinationCodable() throws {
        let dev1 = CameraDevice(
            id: "dev-wide",
            name: "Back Wide",
            position: .back,
            lensType: .wide,
            hasTorch: true,
            isFocusLockSupported: true,
            isExposureLockSupported: true,
            maxZoomFactor: 5.0,
            videoFieldOfView: 65.0
        )
        let dev2 = CameraDevice(
            id: "dev-ultra",
            name: "Back Ultra Wide",
            position: .back,
            lensType: .ultraWide,
            hasTorch: false,
            isFocusLockSupported: true,
            isExposureLockSupported: true,
            maxZoomFactor: 2.0,
            videoFieldOfView: 120.0
        )
        let combo = MultiCamDeviceCombination(
            devices: [dev1, dev2],
            totalHardwareCost: 0.65,
            supportedResolutions: [Resolution(width: 1920, height: 1080)],
            maxSupportedFPS: 30.0
        )

        let data = try JSONEncoder().encode(combo)
        let decoded = try JSONDecoder().decode(MultiCamDeviceCombination.self, from: data)
        #expect(decoded == combo)
        #expect(combo.id == "dev-ultra+dev-wide") // sorted IDs
    }

    @Test("MultiCamState default values")
    func defaultState() {
        let state = MultiCamState()
        #expect(state.mode == .single)
        #expect(state.activeSlots.isEmpty)
        #expect(state.activeFormats.isEmpty)
        #expect(state.layout == nil)
        #expect(state.targetFPS == 30.0)
        #expect(state.sessionState == .idle)
        #expect(state.hardwareCost == 0.0)
    }
}

// MARK: - MultiCamError Tests

@Suite("MultiCamError")
struct MultiCamErrorTests {

    @Test("All MultiCamError cases have non-empty localized descriptions")
    func errorDescriptions() {
        let errors: [MultiCamError] = [
            .multiCamNotSupportedOnHardware,
            .unsupportedMode(mode: .tripleComposite, reason: "Insufficient hardware resources"),
            .unsupportedDeviceCombination(devices: ["wide", "ultra"]),
            .hardwareCostExceeded(currentCost: 1.25, maximumAllowed: 1.0),
            .slotConfigurationFailed(slot: .secondary, reason: "Device busy"),
            .slotNotFound(slot: .tertiary),
            .formatNotMultiCamSupported(deviceID: "wide", formatID: "4k60"),
            .compositionFailed(reason: "Pixel buffer allocation failure"),
            .synchronizationFailed(reason: "Timestamp drift exceeded max tolerance"),
            .fallbackFailed(reason: "No alternative configurations available"),
            .sessionNotRunning,
            .notInitialized
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("MultiCamError Hashable conformance")
    func errorHashable() {
        let e1 = MultiCamError.multiCamNotSupportedOnHardware
        let e2 = MultiCamError.multiCamNotSupportedOnHardware
        let e3 = MultiCamError.sessionNotRunning

        #expect(e1 == e2)
        #expect(e1 != e3)
        let set: Set<MultiCamError> = [e1, e2, e3]
        #expect(set.count == 2)
    }
}
