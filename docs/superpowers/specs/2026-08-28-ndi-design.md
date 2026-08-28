# TamaNDI — NDI Subsystem Specification

- **Date**: 2026-08-28
- **Author**: Antigravity Assistant & NDI Integration Specialist
- **Status**: Approved Design Spec
- **Target Platform**: iOS 18+, Swift 6, AVFoundation, CoreMedia, CoreVideo

---

## 1. Overview & Current Status

The NDI subsystem provides network video and audio streaming for TamaNDI.

### SDK Status
- **Inspection Result**: `Vendor/NDI/` is **not present** in the repository.
- **Strict Policy**: In compliance with `AGENTS.md` ("NEVER invent NDI APIs", "Do NOT fake an NDI implementation"), we do not fake NDI binary packets or pretend C APIs exist.
- **Architecture**: Decoupled backend architecture using `NDIBackend` protocol, `MockNDIBackend` (for testing, UI, and diagnostics), actor-isolated `NDISender`, `NDIVideoSender`, `NDIAudioSender`, `NDIConfiguration`, `NDIStats`, and `NDIMetadata`.
- **Future Concrete Integration**: When the developer drops the official NDI iOS `.xcframework` into `Vendor/NDI/`, a `RealNDIBackend` conforming to `NDIBackend` can be compiled without altering the UI, Camera, or MultiCam subsystems.

---

## 2. Architecture & File Structure

```
Sources/
├── Domain/
│   ├── NDIConfiguration.swift        # Source name, groups, stream settings, video/audio formats
│   ├── NDIStats.swift                # Bitrate, FPS, dropped frames, sent frames, tally telemetry
│   ├── NDIMetadata.swift             # XML metadata, tally state (program/preview)
│   ├── NDIProtocols.swift            # NDISending, NDIBackend, NDIState, NDITally
│   └── NDIError.swift                # Strongly-typed localized NDI errors
└── NDI/
    ├── NDIBackend.swift              # Protocol re-export and backend interfaces
    ├── MockNDIBackend.swift          # Concrete mock implementation for tests and dev
    ├── NDISender.swift               # Actor-isolated sender managing pipelines & lifecycle
    ├── NDIVideoSender.swift          # Video submission pipeline with bounded queue & drop policy
    ├── NDIAudioSender.swift          # Audio submission pipeline for linear PCM buffers
    └── NDIStatisticsCollector.swift  # Rolling bitrate and framerate telemetry collector

Tests/
├── DomainTests/
│   └── NDITypesTests.swift           # Unit tests for domain models, configurations, and errors
└── NDITests/
    ├── MockNDIBackendTests.swift     # Tests for mock backend frame handling & tally simulation
    ├── NDIVideoSenderTests.swift     # Tests for video queueing and backpressure dropping
    ├── NDIAudioSenderTests.swift     # Tests for audio ingestion and sample rate conversions
    ├── NDIStatsTests.swift           # Tests for statistics calculations
    └── NDISenderTests.swift          # Tests for full NDISender actor lifecycle & state
```

---

## 3. Component Details

### 3.1 Domain Layer (`Sources/Domain/`)

- **`NDIConfiguration`**:
  ```swift
  public struct NDIConfiguration: Sendable, Hashable, Codable {
      public var sourceName: String
      public var groups: [String]
      public var targetResolution: Resolution
      public var targetFPS: Double
      public var isClockVideo: Bool
      public var isClockAudio: Bool
  }
  ```

- **`NDITally`**:
  ```swift
  public struct NDITally: Sendable, Hashable, Codable {
      public let inProgram: Bool   // On-air / red tally
      public let inPreview: Bool   // Preview / green tally
  }
  ```

- **`NDIStats`**:
  ```swift
  public struct NDIStats: Sendable, Hashable {
      public let totalVideoFramesSent: Int
      public let totalVideoFramesDropped: Int
      public let totalAudioFramesSent: Int
      public let currentBitrateMbps: Double
      public let actualFPS: Double
      public let tally: NDITally
  }
  ```

- **`NDIBackend` Protocol**:
  ```swift
  public protocol NDIBackend: Sendable {
      func initialize() async throws
      func destroy() async
      func createSender(configuration: NDIConfiguration) async throws -> String
      func destroySender(id: String) async
      func sendVideoFrame(_ frame: VideoFrame, senderID: String) async throws
      func sendAudioBuffer(_ buffer: CMSampleBuffer, senderID: String) async throws
      func sendMetadata(_ metadata: NDIMetadata, senderID: String) async throws
      func getTally(senderID: String) async -> NDITally
  }
  ```

### 3.2 High-Level Pipelines (`Sources/NDI/`)

- **`NDIVideoSender`**:
  - Implements bounded frame queueing (e.g. max buffer depth of 2 frames).
  - Enforces non-blocking backpressure: if the sender backend takes longer than frame interval, older uncompressed frames are dropped immediately to prevent camera queues from stalling.
- **`NDIAudioSender`**:
  - Routes PCM audio buffers from AVFoundation audio capture outputs to the backend.
- **`NDISender`**:
  - Actor managing `NDIBackend` instance lifecycle, session configuration, tally polling/subscription, and telemetry publishing.
