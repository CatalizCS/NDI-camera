// LoggingSubsystem.swift
// Diagnostics — Centralized os.Logger setup for all TamaNDI modules.

#if canImport(os)
import Foundation
import os

/// Centralized logging subsystem providing per-module `os.Logger` instances.
///
/// Usage:
/// ```swift
/// Log.camera.info("Device selected: \(device.name)")
/// Log.ndi.error("Failed to send frame: \(error)")
/// ```
public enum Log {

    // MARK: - Subsystem

    /// The shared subsystem identifier.
    public static let subsystem = "com.tamandicam"

    // MARK: - Per-Module Loggers

    /// Logger for the Camera subsystem.
    public static let camera = Logger(subsystem: subsystem, category: "Camera")

    /// Logger for the Audio subsystem.
    public static let audio = Logger(subsystem: subsystem, category: "Audio")

    /// Logger for the NDI subsystem.
    public static let ndi = Logger(subsystem: subsystem, category: "NDI")

    /// Logger for the Remote Control subsystem.
    public static let remote = Logger(subsystem: subsystem, category: "Remote")

    /// Logger for the Persistence subsystem.
    public static let persistence = Logger(subsystem: subsystem, category: "Persistence")

    /// Logger for the UI layer.
    public static let ui = Logger(subsystem: subsystem, category: "UI")

    /// Logger for the MultiCam subsystem.
    public static let multiCam = Logger(subsystem: subsystem, category: "MultiCam")

    /// Logger for the Diagnostics subsystem itself.
    public static let diagnostics = Logger(subsystem: subsystem, category: "Diagnostics")

    /// Logger for the App lifecycle.
    public static let app = Logger(subsystem: subsystem, category: "App")
}
#endif
