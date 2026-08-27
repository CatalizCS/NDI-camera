# TamaNDI — MultiCam Subsystem Specification

- **Date**: 2026-08-28
- **Author**: Antigravity Assistant & Engineering Lead
- **Status**: Approved Design Spec
- **Target Platform**: iOS 18+, Swift 6, AVFoundation, Metal / CoreImage

---

## 1. Overview & Goals

The `MultiCam` subsystem provides multi-camera capture management for TamaNDI. It enables simultaneous capture from 2 or 3 physical camera lenses on supported iOS hardware using `AVCaptureMultiCamSession`.

### Key Objectives
1. **Dynamic Hardware Detection**: Never assume a device supports multi-cam or specific lens combinations. Dynamically check `AVCaptureMultiCamSession.isMultiCamSupported`, format multi-cam flags (`format.isMultiCamSupported`), and hardware cost budgets (`hardwareCost <= 1.0`).
2. **Flexible Operating Modes**:
   - **Single**: Standard single-lens capture (baseline / fallback).
   - **Dual Independent**: 2 independent camera feeds tagged by slot/ID for separate downstream processing.
   - **Dual Composite**: 2 camera feeds composed into a single unified video stream (PiP, Side-by-Side).
   - **Triple Independent**: 3 independent camera feeds on capable hardware (e.g. iPhone Pro 3-lens).
   - **Triple Composite**: 3 camera feeds composed into a single unified layout (3-way grid/split).
3. **Graceful Fallback**: Dynamically negotiate and downgrade configurations when hardware limits, thermal pressure, or bandwidth budgets are exceeded.
4. **Time-Aligned Synchronization**: Align frame timestamps across multiple asynchronous camera outputs before composite rendering.
5. **High-Performance Composition**: Zero-copy / pool-backed rendering using `CVPixelBufferPool` and Metal / CoreImage without blocking camera capture queues or converting to `UIImage`.

---

## 2. Module & File Architecture

```
Sources/
├── Domain/
│   ├── MultiCamTypes.swift           # MultiCamSlot, CompositeLayout, MultiCamConfiguration, PiPPosition
│   ├── MultiCamProtocols.swift       # MultiCamControlling, MultiCamCapabilityProviding, MultiCamState
│   └── MultiCamError.swift           # MultiCamError enum with localized descriptions
└── MultiCam/
    ├── MultiCamCapabilityDetector.swift # Dynamic combination discovery & hardware cost validation
    ├── MultiCamEngine.swift             # Actor-isolated AVCaptureMultiCamSession controller
    ├── MultiCamEngine+Configuration.swift# Slot configuration, input/output management
    ├── MultiCamFallbackHandler.swift    # Graceful degradation logic (Triple -> Dual -> Single)
    ├── FrameSynchronizer.swift          # Time-window frame alignment for multi-stream synchronization
    ├── MultiCamCompositor.swift         # CoreImage/Metal CVPixelBuffer layout rendering engine
    ├── MultiCamCaptureDelegate.swift    # Per-slot AVCaptureVideoDataOutputSampleBufferDelegate
    └── MultiCamDiagnostics.swift        # Performance metrics, FPS, sync drift, cost telemetry

Tests/
├── DomainTests/
│   └── MultiCamTypesTests.swift         # Layout geometry, slot mapping, configuration tests
└── MultiCamTests/
    ├── MultiCamCapabilityTests.swift    # Combination discovery & cost calculation tests
    ├── FrameSynchronizerTests.swift     # Timestamp matching & jitter tolerance tests
    ├── MultiCamFallbackTests.swift      # Graceful downgrade & error handling tests
    └── MultiCamCompositorTests.swift    # Composite layout and pixel buffer tests
```

---

## 3. Detailed Component Specifications

### 3.1 Domain Models (`Sources/Domain/MultiCamTypes.swift`)

- **`MultiCamSlot`**:
  ```swift
  public enum MultiCamSlot: String, Sendable, Codable, CaseIterable, Hashable {
      case primary
      case secondary
      case tertiary
  }
  ```

- **`PiPPosition`**:
  ```swift
  public enum PiPPosition: String, Sendable, Codable, CaseIterable, Hashable {
      case topLeft
      case topRight
      case bottomLeft
      case bottomRight
  }
  ```

- **`CompositeLayout`**:
  ```swift
  public enum CompositeLayout: Sendable, Codable, Hashable {
      case pictureInPicture(position: PiPPosition, sizeFraction: Double)
      case sideBySide(splitRatio: Double, isVertical: Bool)
      case primaryWithDualInsets(first: PiPPosition, second: PiPPosition, sizeFraction: Double)
      case threeGrid(primaryOnTop: Bool)
      case threeSplitHorizontal
  }
  ```

- **`MultiCamVideoFrame`**:
  ```swift
  public struct MultiCamVideoFrame: Sendable {
      public let slot: MultiCamSlot
      public let cameraID: String
      public let sampleBuffer: CMSampleBuffer
      public let timestamp: CMTime
  }
  ```

- **`MultiCamDeviceCombination`**:
  ```swift
  public struct MultiCamDeviceCombination: Sendable, Hashable, Identifiable {
      public var id: String { devices.map(\.id).sorted().joined(separator: "+") }
      public let devices: [CameraDevice]
      public let totalHardwareCost: Float
      public let supportedResolutions: [Resolution]
      public let maxSupportedFPS: Double
  }
  ```

- **`MultiCamState`**:
  ```swift
  public struct MultiCamState: Sendable, Hashable {
      public let mode: CameraMode
      public let activeSlots: [MultiCamSlot: CameraDevice]
      public let activeFormats: [MultiCamSlot: CaptureFormat]
      public let layout: CompositeLayout?
      public let targetFPS: Double
      public let sessionState: StreamState
      public let hardwareCost: Float
  }
  ```

---

### 3.2 Dynamic Capability Detection (`Sources/MultiCam/MultiCamCapabilityDetector.swift`)

The detector performs strict runtime interrogation:
1. Verify `AVCaptureMultiCamSession.isMultiCamSupported`. If false, returns empty combinations.
2. Query available physical devices (Wide, Ultra-Wide, Telephoto, Front/TrueDepth).
3. Compute all valid 2-device combinations:
   - For each pair $(D_1, D_2)$, find formats where `format.isMultiCamSupported == true`.
   - Calculate total hardware cost using `AVCaptureDeviceInput.hardwareCost` + `AVCaptureVideoDataOutput.hardwareCost`.
   - Validate that `totalHardwareCost <= 1.0` and system pressure cost is sustainable.
4. Compute all valid 3-device combinations $(D_1, D_2, D_3)$ using the same criteria.
5. Export `MultiCamCapabilityMatrix` containing all supported combinations and maximum allowable resolutions/framerates.

---

### 3.3 MultiCam Engine (`Sources/MultiCam/MultiCamEngine.swift`)

The actor serializes all session operations:
- Owns `AVCaptureMultiCamSession`.
- Creates dedicated `AVCaptureDeviceInput` and `AVCaptureVideoDataOutput` per slot.
- Configures dedicated serial `DispatchQueue` per slot (`com.tamandicam.multicam.slot.<slot>`).
- Exposes two output streams:
  1. `independentFrames: AsyncStream<MultiCamVideoFrame>` for independent mode.
  2. `compositeFrames: AsyncStream<VideoFrame>` for composite mode.
- Manages dynamic reconfiguration between Single, Dual, and Triple modes without reallocating the underlying session when possible.

---

### 3.4 Frame Synchronization (`Sources/MultiCam/FrameSynchronizer.swift`)

When running in Composite mode, camera feeds must be synchronized before rendering:
- Ring-buffer queue for each active slot.
- Matches frames based on `CMSampleBufferGetPresentationTimeStamp`.
- Matching tolerance: $\Delta t \le \text{tolerance}$ (e.g. $\pm 16.6\text{ ms}$ at 30 FPS).
- Synchronization policy:
  - If all active slots have frames within tolerance, emit a synchronized tuple `[MultiCamSlot: CMSampleBuffer]`.
  - If a frame is dropped or delayed beyond the tolerance window, use the latest valid sample buffer up to an age limit, or drop incomplete sets to preserve real-time latency.

---

### 3.5 High-Performance Compositor (`Sources/MultiCam/MultiCamCompositor.swift`)

- Manages `CVPixelBufferPool` for target output resolution (e.g. 1080p60 / 4K30).
- Uses `CIContext` with an underlying Metal device (`MTLCreateSystemDefaultDevice()`).
- Renders PiP and split layouts into destination `CVPixelBuffer`s without copying memory into CPU user-space.
- Encapsulates composited buffers into `VideoFrame` and streams them downstream.

---

### 3.6 Diagnostics & Fallback (`MultiCamDiagnostics.swift`, `MultiCamFallbackHandler.swift`)

- **Telemetry**: Real-time FPS per slot, drop rate, average synchronization jitter ($\mu\text{s}$), and session hardware cost.
- **Graceful Fallback**:
  - If Triple mode fails configuration due to device cost limit $\to$ automatically downgrade to Dual mode (Primary + Secondary) with a diagnostic warning.
  - If Dual mode fails or MultiCam is unsupported $\to$ fallback to Single camera mode.

---

## 4. Verification Plan

1. **Unit Tests**:
   - Layout coordinate and geometry calculations.
   - Capability detection matrix and format compatibility filtering.
   - Synchronizer timestamp matching with synthetic jitter and drop conditions.
   - Fallback decision transitions.
2. **Build and Code Review**:
   - Verify complete Swift 6 strict concurrency conformance (`Sendable`, actors, no unsafe shared state).
   - Verify zero fake APIs and exact AVFoundation/CoreMedia/Metal types.
3. **Documentation**:
   - Generate `docs/agents/MULTICAM_REPORT.md` documenting architecture, test coverage, and capabilities.
