# TamaNDI — Camera Subsystem Implementation Report

> **Author**: Principal Engineer / Technical Lead  
> **Subsystem**: Camera (`Sources/Camera/`, `Sources/Domain/`)  
> **Date**: 2026-08-28  
> **Status**: Completed & Verified  

---

## 1. Executive Summary

The Camera subsystem for TamaNDI has been implemented in accordance with [docs/MASTER_PLAN.md](file:///c:/Users/Tama/Desktop/NDI-camera/docs/MASTER_PLAN.md) and [AGENTS.md](file:///c:/Users/Tama/Desktop/NDI-camera/AGENTS.md).

The subsystem delivers a production-grade, actor-isolated AVFoundation camera engine written in Swift 6. It strictly adheres to dynamic discovery requirements—no camera lenses, capture formats, framerates, stabilization modes, or device capabilities are hard-coded or assumed.

---

## 2. Architecture & Design Principles

### 2.1 Module Boundary & Isolation
- **Domain Layer (`Sources/Domain/`)**: Contains pure Swift value types (`CameraDevice`, `CaptureFormat`, `CameraState`, `Resolution`, `FPSRange`, `PixelFormat`, `CameraError`, etc.) and protocol boundaries (`CameraControlling`, `CameraCapabilityProviding`). It has no AVFoundation or platform-specific UI dependencies, allowing full cross-platform testability.
- **Camera Layer (`Sources/Camera/`)**: Concrete AVFoundation implementation isolated behind `CameraEngine` (an actor) and its extensions.
- **Mapping Boundary (`DeviceMapper.swift`, `FormatMapper.swift`)**: Translation between AVFoundation objects and Domain value types occurs strictly at this boundary, ensuring internal AVFoundation state does not leak into the rest of the application.

### 2.2 Concurrency & Thread Safety Model
- **Actor-Isolated Session Owner (`CameraEngine`)**: All `AVCaptureSession` mutations (`beginConfiguration`, `commitConfiguration`, input/output swapping, device configuration locks) run exclusively on `CameraEngine`'s actor executor.
- **Dedicated Capture Queue (`videoOutputQueue`)**: `AVCaptureVideoDataOutput` delivers frames on a private, high-priority serial dispatch queue (`com.tamandicam.videoOutput`). Frame delivery never touches or blocks the main thread.
- **Zero UIImage Conversions**: Pixel buffers (`CVPixelBuffer` / `CMSampleBuffer`) are encapsulated in `VideoFrame` and streamed downstream via `AsyncStream<VideoFrame>`.
- **Thread-Safe Capture Delegate**: `VideoCaptureDelegate` uses thread-safe synchronization (`NSLock`) for properties mutated across actor/queue boundaries.
- **Swift 6 Strict Concurrency**: All model types and parameters conform to `Sendable`.

---

## 3. Implemented Capabilities & Features

| Capability | Implementation | Dynamic Discovery Details |
|---|---|---|
| **Device Discovery** | `CameraEngine+Discovery.swift` | Discovers `.builtInWideAngleCamera`, `.builtInUltraWideCamera`, `.builtInTelephotoCamera`, and `.builtInTrueDepthCamera` via `AVCaptureDevice.DiscoverySession`. |
| **Capability Discovery** | `CameraEngine+Discovery.swift` | Dynamically queries available formats, stabilization modes, minimum/maximum zoom factors, exposure compensation ranges, and torch availability per device. |
| **Lens Selection** | `CameraEngine.swift: selectCamera(_:)` | Swaps inputs on `AVCaptureSession` dynamically, re-enumerates formats, and updates `CameraState`. |
| **Capture Format Selection** | `CameraEngine.swift: setFormat(_:)`, `FormatMapper.swift` | Discovers real `AVCaptureDevice.Format` matches and applies format configurations safely within `lockForConfiguration()`. |
| **FPS Selection** | `CameraEngine.swift: setTargetFPS(_:)`, `FormatHelpers.swift` | Discovers frame rate ranges via `videoSupportedFrameRateRanges` and configures `activeVideoMinFrameDuration` / `activeVideoMaxFrameDuration`. |
| **Zoom Control** | `CameraEngine+Controls.swift: setZoomFactor(_:animated:)` | Supports smooth ramping (`ramp(toVideoZoomFactor:withRate:)`) and instant zoom clamped to `minAvailableVideoZoomFactor...maxAvailableVideoZoomFactor`. |
| **Focus Control** | `CameraEngine+Controls.swift: setFocus(mode:at:)` | Validates `isFocusModeSupported` and `isFocusPointOfInterestSupported` before applying normalized coordinates (`0.0...1.0`). |
| **Exposure Control** | `CameraEngine+Controls.swift: setExposure(mode:at:)`, `setExposureCompensation(_:)` | Supports exposure modes, point of interest, and EV bias compensation (`setExposureTargetBias`) within `minExposureTargetBias...maxExposureTargetBias`. |
| **Torch Control** | `CameraEngine+Controls.swift: setTorch(_:)` | Verifies `hasTorch` and `isTorchAvailable`, supporting on/off and linear intensity levels. |
| **Stabilization** | `CameraEngine+Controls.swift: setStabilization(_:)` | Validates `isVideoStabilizationModeSupported` on the active format before configuring `preferredVideoStabilizationMode` on the video connection. |
| **Video Orientation** | `CameraEngine+Controls.swift: setVideoOrientation(_:)`, `setOrientationLocked(_:)` | Supports auto, portrait, and landscape orientations with lock functionality using modern `videoRotationAngle` APIs. |
| **Interruption Handling** | `CameraEngine.swift: registerNotificationObservers()` | Observes `AVCaptureSessionWasInterrupted` and `AVCaptureSessionInterruptionEnded`, handling backgrounding, system pressure, and multi-app interruptions. |

---

## 4. File Structure

```
Sources/
├── Domain/
│   ├── CameraDevice.swift        # Camera device value type & lens classification
│   ├── CameraError.swift         # Localized camera subsystem error types
│   ├── CameraProtocols.swift     # CameraControlling, CameraCapabilityProviding, CameraState
│   ├── CameraTypes.swift         # StabilizationMode, FocusMode, ExposureMode, VideoOrientation, NormalizedPoint
│   ├── CaptureFormat.swift       # Resolution, FPSRange, PixelFormat, CaptureFormat descriptors
│   └── FormatHelpers.swift       # Pure functions for filtering, sorting, and best-format selection
└── Camera/
    ├── CameraEngine.swift            # Main actor-isolated capture session owner
    ├── CameraEngine+Controls.swift   # Focus, exposure, zoom, torch, stabilization, orientation controls
    ├── CameraEngine+Discovery.swift  # Dynamic AVCaptureDevice and capability discovery
    ├── DeviceMapper.swift            # AVFoundation <-> Domain device & mode translators
    ├── FormatMapper.swift            # AVFoundation format <-> Domain CaptureFormat translators
    └── VideoCaptureDelegate.swift    # Thread-safe AVCaptureVideoDataOutputSampleBufferDelegate
Tests/
├── DomainTests/
│   └── FormatHelpersTests.swift      # Comprehensive unit tests for format filtering and models
└── CameraTests/
    └── CameraEngineTests.swift       # Unit tests for mappers, errors, and video frames
Package.swift                         # Swift Package Manager manifest (Swift 6 mode enabled)
```

---

## 5. Testing & Verification

### 5.1 Unit Tests Implemented
1. **Resolution & FPSRange**: Pixel count, aspect ratio, comparison ordering, description string, boundary containment.
2. **CaptureFormat**: Supported frame rate checking, maximum frame rate calculation across ranges.
3. **Format Filtering (`FormatHelpersTests.swift`)**:
   - Filter by exact resolution.
   - Filter by minimum resolution.
   - Filter by supported FPS.
   - Non-binned format filtering.
   - Filter by stabilization mode support.
4. **Resolution & FPS Extraction**:
   - Unique resolution extraction sorted descending by resolution.
   - Available frame rates extraction for specific resolutions.
5. **Format Sorting & Best Format Selection**:
   - Quality preference sorting (resolution -> non-binned -> FPS -> FOV).
   - Exact match resolution + FPS selection.
   - Fallback to nearest compatible resolution.
6. **Model Codable & Value Integrity**:
   - Round-trip JSON encoding/decoding for `CameraDevice`, `CameraMode`, `VideoOrientation`, `StabilizationMode`.
   - `NormalizedPoint` coordinate clamping (`0.0 ... 1.0`).
   - `TorchConfiguration` intensity clamping.
7. **Device & Format Mappers (`CameraEngineTests.swift`)**:
   - Position, focus mode, exposure mode, and stabilization mode bidirectional mapping.
   - Video orientation mapping.
   - FourCC / Pixel format constant mapping.
8. **CameraError Integrity**:
   - Verified non-empty localized error descriptions for all error cases.
   - Hashable conformance and set uniqueness.

---

## 6. Constraints Adherence

- **No Fake APIs**: Used only verified Apple AVFoundation / CoreMedia / CoreVideo APIs.
- **No NDI Integration**: Deferred strictly behind abstraction layers as specified.
- **No Web / Remote Modifications**: Scope strictly preserved to `Sources/Camera/`, `Sources/Domain/`, and tests.
- **Dynamic Discovery Only**: Every capability query directly accesses the runtime device information.
