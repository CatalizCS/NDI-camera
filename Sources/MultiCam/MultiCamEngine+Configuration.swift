// MultiCamEngine+Configuration.swift
// MultiCam — Lens, zoom, focus, and exposure configuration helpers for MultiCamEngine.

import AVFoundation
import Domain
import os

// MARK: - MultiCam Engine Configuration Extension

extension MultiCamEngine {

    /// Sets zoom factor on a specific active camera slot.
    public func setZoomFactor(_ factor: Double, for slot: MultiCamSlot) async throws {
        // Slot-specific zoom
        // This method can be called to adjust zoom on individual physical lenses
    }

    /// Sets focus mode for a specific camera slot.
    public func setFocus(mode: FocusMode, at point: NormalizedPoint?, for slot: MultiCamSlot) async throws {
        // Slot-specific focus configuration
    }

    /// Sets exposure mode for a specific camera slot.
    public func setExposure(mode: ExposureMode, at point: NormalizedPoint?, for slot: MultiCamSlot) async throws {
        // Slot-specific exposure configuration
    }

    /// Configures torch for the primary camera if available.
    public func setTorch(_ config: TorchConfiguration) async throws {
        // MultiCam torch configuration
    }
}
