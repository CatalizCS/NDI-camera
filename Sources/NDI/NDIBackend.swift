// NDIBackend.swift
// NDI — Backend protocol and abstraction interfaces for the NDI streaming subsystem.

import Foundation
import CoreMedia
import Domain

// Re-export NDIBackend protocol from Domain for convenience within the NDI module.
@_exported import struct Domain.NDIConfiguration
@_exported import struct Domain.NDIStats
@_exported import struct Domain.NDIMetadata
@_exported import struct Domain.NDITally
@_exported import enum Domain.NDIVideoFormat
@_exported import enum Domain.NDIStreamState
@_exported import enum Domain.NDIError
@_exported import protocol Domain.NDIBackend
@_exported import protocol Domain.NDISending
