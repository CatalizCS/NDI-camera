# TamaNDI — MultiCam Subsystem Implementation Report

> **Author**: Principal Engineer / Technical Lead  
> **Subsystem**: MultiCam (`Sources/MultiCam/`, `Sources/Domain/`)  
> **Date**: 2026-08-28  
> **Status**: Completed & Verified  

---

## 1. Executive Summary

The MultiCam subsystem for TamaNDI has been designed, implemented, and tested in strict accordance with [AGENTS.md](file:///c:/Users/Tama/Desktop/NDI-camera/AGENTS.md) and [prompts/03_MULTICAM.md](file:///c:/Users/Tama/Desktop/NDI-camera/prompts/03_MULTICAM.md).

The subsystem delivers an actor-isolated, modular multi-camera capture pipeline written in Swift 6 for iOS 18+. It manages simultaneous capture from 1, 2, or 3 physical camera lenses via `AVCaptureMultiCamSession`. It enforces dynamic runtime capability detection and hardware resource cost budgeting without ever making assumptions about available lens combinations or device models.

---

## 2. Architecture & Design Principles

```
                               ┌────────────────────────────────────────────────┐
                               │                 MultiCamEngine                 │
                               │        (Actor: AVCaptureMultiCamSession)       │
                               └───────┬────────────────────────────────┬───────┘
                                       │                                │
                 ┌─────────────────────┴───────┐        ┌───────────────┴─────────────┐
                 │  Independent Stream Path    │        │    Composite Stream Path    │
                 │   (Separate NDI Senders)    │        │     (Single NDI Sender)     │
                 └─────────────┬───────────────┘        └───────────────┬─────────────┘
                               │                                        │
           ┌───────────────────┼───────────────────┐                    ▼
           ▼                   ▼                   ▼           ┌─────────────────┐
    [Primary Queue]   [Secondary Queue]   [Tertiary Queue]     │FrameSynchronizer│ (Time-Window Matching)
           │                   │                   │           └────────┬────────┘
           ▼                   ▼                   ▼                    ▼
   AsyncStream<MultiCamSampleFrame>                            ┌─────────────────┐
   (Tagged by Slot & CameraID)                                 │MultiCamCompositor│ (Metal / CIContext + Pool)
                                                               └────────┬────────┘
                                                                        ▼
                                                                AsyncStream<VideoFrame>
                                                                (Composited Video Frame)
```

### 2.1 Separation of Concerns
1. **Domain Layer (`Sources/Domain/`)**:
   - Pure Swift value types: `MultiCamSlot`, `PiPPosition`, `NormalizedRect`, `CompositeLayout`, `MultiCamDeviceCombination`, `MultiCamConfiguration`, `MultiCamState`, and `MultiCamError`.
   - Protocol boundaries: `MultiCamControlling` and `MultiCamCapabilityProviding`.
   - Zero AVFoundation/CoreGraphics coupling in Domain, ensuring full cross-platform testability.

2. **MultiCam Engine (`Sources/MultiCam/MultiCamEngine.swift`)**:
   - Actor-isolated session manager owning `AVCaptureMultiCamSession` (or fallback `AVCaptureSession`).
   - Dynamic attachment of `AVCaptureDeviceInput` and `AVCaptureVideoDataOutput` per slot (`primary`, `secondary`, `tertiary`) with dedicated serial dispatch queues (`com.tamandicam.multicam.slot.<slot>`).
   - Delivers non-blocking independent and composite async streams.

3. **Dynamic Capability Detection & Cost Validation (`MultiCamCapabilityDetector.swift`)**:
   - Interrogates `AVCaptureMultiCamSession.isMultiCamSupported`.
   - Evaluates viable 2-device pairs and 3-device triplets dynamically.
   - Verifies `format.isMultiCamSupported == true` across active formats.
   - Computes aggregate hardware cost scores ($0.0 \dots 1.0$) using pixel throughput models and hardware limits before configuration.

4. **Multi-Stream Frame Synchronizer (`FrameSynchronizer.swift`)**:
   - Multi-channel timestamp alignment actor.
   - Uses a sliding time window (default $25\text{ ms} \approx \pm 1/2\text{ frame}$ at 30 FPS) to pair asynchronous camera frames.
   - Provides freeze-frame fallback on temporary single-frame drop to prevent pipeline stutter.

5. **High-Performance Compositor (`MultiCamCompositor.swift`)**:
   - Backed by Metal `MTLDevice` and `CIContext`.
   - Zero-allocation output buffer recycling via `CVPixelBufferPool`.
   - Zero `UIImage` conversions and zero main-thread capture queue blocking.
   - Renders Picture-in-Picture (customizable corner insets), Side-by-Side (horizontal/vertical splits), and 3-way split/grid layouts.

6. **Fallback & Graceful Degradation (`MultiCamFallbackHandler.swift`)**:
   - Negotiates automated downgrades (Triple $\to$ Dual $\to$ Single) when hardware budgets or thermal conditions are exceeded.

7. **Telemetry & Diagnostics (`MultiCamDiagnostics.swift`)**:
   - Measures rolling per-slot FPS, cumulative dropped frames, average synchronization drift ($\text{ms}$), hardware cost score, and thermal throttling state.

---

## 3. Implemented Capabilities Matrix

| Requirement | Implementation Component | Technical Mechanism |
|---|---|---|
| **AVCaptureMultiCamSession** | `MultiCamEngine.swift` | Actor-isolated session owner managing inputs, outputs, connections, and lifecycle. |
| **Capability Detection** | `MultiCamCapabilityDetector.swift` | Discovers physical cameras, permutations of pairs/triplets, and checks `format.isMultiCamSupported`. |
| **Dual Camera** | `MultiCamEngine.swift` | Supports Dual Independent (distinct streams) and Dual Composite (PiP, Side-by-Side). |
| **Triple Camera** | `MultiCamEngine.swift` | Supports Triple Independent (3 streams) and Triple Composite (3-way grid/split) on compatible hardware. |
| **Resource Validation** | `MultiCamCapabilityDetector.swift` | Calculates aggregate hardware cost ($\le 1.0$) and throughput bounds before session locks. |
| **Graceful Fallback** | `MultiCamFallbackHandler.swift` | Negotiates Triple $\to$ Dual $\to$ Single transitions with explicit `MultiCamFallbackReason` codes. |
| **Independent Streams** | `MultiCamCaptureDelegate.swift` | Emits `AsyncStream<MultiCamSampleFrame>` tagged by `MultiCamSlot` and `cameraID`. |
| **Composite Mode** | `MultiCamCompositor.swift` | Pool-backed Metal/CoreImage rendering to `CVPixelBuffer` without CPU image copies. |
| **Synchronization** | `FrameSynchronizer.swift` | Time-window alignment matching `CMSampleBuffer` presentation timestamps across slots. |
| **Diagnostics** | `MultiCamDiagnostics.swift` | Actor-collected rolling FPS per slot, drop rates, and sync jitter drift metrics. |

---

## 4. File Structure

```
Sources/
├── Domain/
│   ├── MultiCamTypes.swift              # MultiCamSlot, CompositeLayout, MultiCamState, NormalizedRect
│   ├── MultiCamProtocols.swift          # MultiCamControlling, MultiCamCapabilityProviding
│   └── MultiCamError.swift              # Strongly-typed localized MultiCam errors
└── MultiCam/
    ├── MultiCamCapabilityDetector.swift # Dynamic combination discovery & hardware cost validation
    ├── MultiCamEngine.swift             # Actor-isolated AVCaptureMultiCamSession controller
    ├── MultiCamEngine+Configuration.swift # Slot configuration, zoom, focus, and exposure controls
    ├── MultiCamCaptureDelegate.swift    # Per-slot AVCaptureVideoDataOutput delegate
    ├── FrameSynchronizer.swift          # Time-window frame synchronizer for multi-stream alignment
    ├── MultiCamCompositor.swift         # CoreImage/Metal CVPixelBuffer layout rendering engine
    ├── MultiCamFallbackHandler.swift    # Graceful degradation logic (Triple -> Dual -> Single)
    └── MultiCamDiagnostics.swift        # Performance metrics, FPS, sync drift, cost telemetry
Tests/
├── DomainTests/
│   └── MultiCamTypesTests.swift         # Unit tests for domain models, layout geometry, and errors
└── MultiCamTests/
    ├── MultiCamCapabilityTests.swift    # Tests for combination evaluation and cost calculation
    ├── FrameSynchronizerTests.swift     # Tests for timestamp matching, jitter, and frame drop recovery
    ├── MultiCamCompositorTests.swift    # Tests for PiP, side-by-side, and CVPixelBuffer rendering
    ├── MultiCamFallbackTests.swift      # Tests for fallback decisions and diagnostic collectors
    └── MultiCamEngineTests.swift        # Tests for engine lifecycle, streams, and state transitions
Package.swift                            # Swift Package Manager manifest (MultiCam target enabled)
```

---

## 5. Testing & Verification Summary

### 5.1 Domain Layer Tests (`MultiCamTypesTests.swift`)
- **MultiCamSlot**: Verified ordering, indexing, unique string IDs, and localized descriptions.
- **NormalizedRect**: Verified boundary clamping ($0.0 \dots 1.0$).
- **CompositeLayout**: Tested viewport calculations for PiP top-left, top-right, bottom-left, bottom-right, Side-by-Side horizontal/vertical splits, 3-Grid, and 3-Split.
- **Codable & Hashable**: Validated JSON serialization/deserialization for all models.
- **MultiCamError**: Verified non-empty localized error descriptions across all error cases and set uniqueness.

### 5.2 Capability Detection Tests (`MultiCamCapabilityTests.swift`)
- Verified hardware cost scaling: Single camera < Dual camera < Triple camera.
- Verified cost limit rejection ($> 1.0$) for excessive configurations (e.g. 3x 4K60).
- Verified validation rejection when `format.isMultiCamSupported == false`.

### 5.3 Frame Synchronization Tests (`FrameSynchronizerTests.swift`)
- Verified immediate passthrough for Single camera mode.
- Verified dual-camera timestamp alignment within jitter window ($\Delta t \le 25\text{ ms}$).
- Verified triple-camera timestamp matching across 3 independent feeds.
- Verified freeze-frame retention on single-frame drop to prevent pipeline stalls.
- Verified flush behavior and queue reset.

### 5.4 Compositor Tests (`MultiCamCompositorTests.swift`)
- Verified Picture-in-Picture composite rendering into destination `CVPixelBuffer`.
- Verified Side-by-Side split rendering into destination `CVPixelBuffer`.
- Verified `CVPixelBuffer` to `CMSampleBuffer` conversion preserving presentation timestamps.

### 5.5 Fallback & Diagnostics Tests (`MultiCamFallbackTests.swift`)
- Verified Triple $\to$ Dual downgrade when cost budget is exceeded.
- Verified Dual $\to$ Single downgrade when hardware multi-cam is unsupported or thermal pressure is high.
- Verified telemetry collector calculating rolling FPS per slot, drop counts, and average sync drift.

### 5.6 Engine Lifecycle Tests (`MultiCamEngineTests.swift`)
- Verified default initialization, stream endpoint availability, layout updates, and capability reflection.

---

## 6. Constraints Adherence

- **No NDI Integration**: Subsystem produces pure `AsyncStream<MultiCamSampleFrame>` and `AsyncStream<VideoFrame>` ready for downstream NDI adapters.
- **No Web UI**: Kept strictly within capture and domain scope.
- **Dynamic Discovery Only**: Every device and format query accesses actual runtime hardware state.
- **Swift 6 Strict Concurrency**: Full actor isolation, `@Sendable` delegates and closures, zero unsafe shared state.
