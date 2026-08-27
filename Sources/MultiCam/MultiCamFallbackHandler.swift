// MultiCamFallbackHandler.swift
// MultiCam — Graceful degradation logic for unsupported or resource-constrained camera setups.
// Negotiates smooth fallbacks (Triple -> Dual -> Single) with descriptive reason codes.

import Foundation
import Domain
import os

// MARK: - Fallback Reason

/// Reason why a multi-camera configuration was downgraded or rejected.
public enum MultiCamFallbackReason: Sendable, Hashable, CustomStringConvertible {
    case multiCamNotSupported
    case costBudgetExceeded(cost: Float)
    case thermalPressureHigh
    case deviceUnavailable(deviceID: String)
    case formatIncompatible(reason: String)
    case manualRequest

    public var description: String {
        switch self {
        case .multiCamNotSupported:
            "AVCaptureMultiCamSession is not supported on this device hardware"
        case .costBudgetExceeded(let cost):
            "Hardware resource cost of \(String(format: "%.2f", cost)) exceeded maximum budget of 1.0"
        case .thermalPressureHigh:
            "System thermal pressure elevated — throttling multi-camera feeds"
        case .deviceUnavailable(let id):
            "Camera device '\(id)' is no longer accessible or in use by another process"
        case .formatIncompatible(let reason):
            "Capture format is incompatible with multi-camera mode: \(reason)"
        case .manualRequest:
            "User or system requested configuration change"
        }
    }
}

// MARK: - Fallback Decision

/// The resulting configuration after applying graceful fallback negotiation.
public struct FallbackDecision: Sendable, Hashable {
    /// Target camera operating mode after downgrade.
    public let targetMode: CameraMode

    /// Recommended slot mappings to preserve.
    public let retainedSlots: [MultiCamSlot: CameraDevice]

    /// The triggering reason for the fallback.
    public let reason: MultiCamFallbackReason

    /// User-friendly explanation string.
    public let explanation: String

    public init(
        targetMode: CameraMode,
        retainedSlots: [MultiCamSlot: CameraDevice],
        reason: MultiCamFallbackReason,
        explanation: String
    ) {
        self.targetMode = targetMode
        self.retainedSlots = retainedSlots
        self.reason = reason
        self.explanation = explanation
    }
}

// MARK: - MultiCam Fallback Handler

/// Evaluates constraint violations and computes the optimal fallback configuration.
public final class MultiCamFallbackHandler: Sendable {

    private let logger = Logger(subsystem: "com.tamandicam", category: "MultiCamFallbackHandler")

    public init() {}

    /// Determines the best fallback configuration when a multi-camera mode cannot be sustained.
    public func negotiateFallback(
        requestedMode: CameraMode,
        currentSlots: [MultiCamSlot: CameraDevice],
        availableCombinations: [MultiCamDeviceCombination],
        reason: MultiCamFallbackReason
    ) -> FallbackDecision {
        logger.warning("Negotiating fallback for mode \(requestedMode.rawValue): \(reason.description)")

        // 1. If MultiCam is not supported at all on hardware, fall back directly to Single
        if case .multiCamNotSupported = reason {
            let primaryDevice = currentSlots[.primary] ?? selectPrimaryDevice(from: currentSlots)
            return FallbackDecision(
                targetMode: .single,
                retainedSlots: primaryDevice.map { [.primary: $0] } ?? [:],
                reason: reason,
                explanation: "Downgraded to Single Camera because multi-camera capture is not supported on this device."
            )
        }

        // 2. Triple Camera fallback -> Attempt Dual Camera
        if requestedMode == .tripleIndependent || requestedMode == .tripleComposite {
            let isComposite = (requestedMode == .tripleComposite)
            let dualMode: CameraMode = isComposite ? .dualComposite : .dualIndependent

            // Check if there is a viable dual combination retaining primary and secondary
            if let prim = currentSlots[.primary], let sec = currentSlots[.secondary] {
                let pairIDs = Set([prim.id, sec.id])
                let pairExists = availableCombinations.contains { combo in
                    let comboIDs = Set(combo.devices.map(\.id))
                    return pairIDs.isSubset(of: comboIDs)
                }

                if pairExists {
                    return FallbackDecision(
                        targetMode: dualMode,
                        retainedSlots: [.primary: prim, .secondary: sec],
                        reason: reason,
                        explanation: "Downgraded from Triple to Dual Camera to stay within hardware resource budgets."
                    )
                }
            }

            // If primary + secondary pair is not viable, pick any valid 2-device combination with primary
            if let prim = currentSlots[.primary],
               let validDual = availableCombinations.first(where: { $0.devices.count == 2 && $0.devices.contains(where: { $0.id == prim.id }) }) {
                let otherDevice = validDual.devices.first(where: { $0.id != prim.id })!
                return FallbackDecision(
                    targetMode: dualMode,
                    retainedSlots: [.primary: prim, .secondary: otherDevice],
                    reason: reason,
                    explanation: "Downgraded to Dual Camera using compatible device '\(otherDevice.name)'."
                )
            }

            // If no dual combination works, fallback to single
            let primaryDevice = currentSlots[.primary] ?? selectPrimaryDevice(from: currentSlots)
            return FallbackDecision(
                targetMode: .single,
                retainedSlots: primaryDevice.map { [.primary: $0] } ?? [:],
                reason: reason,
                explanation: "Downgraded to Single Camera because no dual camera combination is viable under current constraints."
            )
        }

        // 3. Dual Camera fallback -> Fall back to Single
        if requestedMode == .dualIndependent || requestedMode == .dualComposite {
            let primaryDevice = currentSlots[.primary] ?? selectPrimaryDevice(from: currentSlots)
            return FallbackDecision(
                targetMode: .single,
                retainedSlots: primaryDevice.map { [.primary: $0] } ?? [:],
                reason: reason,
                explanation: "Downgraded from Dual to Single Camera (\(reason.description))."
            )
        }

        // 4. Single Camera fallback (already single)
        let primaryDevice = currentSlots[.primary] ?? selectPrimaryDevice(from: currentSlots)
        return FallbackDecision(
            targetMode: .single,
            retainedSlots: primaryDevice.map { [.primary: $0] } ?? [:],
            reason: reason,
            explanation: "Single camera configuration active."
        )
    }

    private func selectPrimaryDevice(from slots: [MultiCamSlot: CameraDevice]) -> CameraDevice? {
        slots[.primary] ?? slots[.secondary] ?? slots[.tertiary]
    }
}
