# MultiCam Subsystem Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a production-grade, modular `MultiCam` subsystem for TamaNDI on iOS 18+ / Swift 6 supporting single, dual, and triple camera capture, dynamic capability detection, independent streams, composite rendering, frame synchronization, graceful fallback, and comprehensive tests.

**Architecture:** Actor-isolated engine (`MultiCamEngine`) managing an `AVCaptureMultiCamSession` with dedicated per-slot capture delegates and serial queues. Decoupled domain models in `Sources/Domain/`, dynamic capability detection and resource budgeting in `MultiCamCapabilityDetector`, time-window timestamp alignment in `FrameSynchronizer`, and zero-copy pool-backed composite rendering in `MultiCamCompositor`.

**Tech Stack:** Swift 6 (Strict Concurrency), iOS 18+, AVFoundation (`AVCaptureMultiCamSession`, `AVCaptureDeviceInput`, `AVCaptureVideoDataOutput`), CoreMedia, CoreVideo (`CVPixelBufferPool`), Metal / CoreImage (`CIContext`), Swift Testing framework.

## Global Constraints

- **Platform:** iOS 18+, Swift 6 (`.swiftLanguageMode(.v6)`), AVFoundation, CoreMedia, CoreVideo, Metal.
- **Dynamic Discovery Only:** Never assume camera combinations, lens availability, format support, or hardware cost budgets. Always inspect `AVCaptureMultiCamSession.isMultiCamSupported`, `format.isMultiCamSupported`, and hardware costs dynamically.
- **Modularity:** No monolithic CameraManager. Keep capture, capability discovery, synchronization, composition, diagnostics, and domain models cleanly separated.
- **Performance:** Zero unnecessary frame copies, zero `UIImage` conversions in capture/render paths, no main-thread processing, no blocking capture queues.
- **Concurrency:** Swift Concurrency (`Sendable`, actors, no unsafe shared mutable state).
- **Scope Limitations:** Do not implement NDI or Web UI in this subsystem.

---

### Task 1: Domain Models, Protocols, and Errors

**Files:**
- Create: `Sources/Domain/MultiCamTypes.swift`
- Create: `Sources/Domain/MultiCamProtocols.swift`
- Create: `Sources/Domain/MultiCamError.swift`
- Modify: `Package.swift` (add MultiCam target and MultiCamTests test target)
- Create: `Tests/DomainTests/MultiCamTypesTests.swift`

**Interfaces:**
- Produces: `MultiCamSlot`, `PiPPosition`, `CompositeLayout`, `MultiCamDeviceCombination`, `MultiCamState`, `MultiCamControlling`, `MultiCamCapabilityProviding`, `MultiCamError`

- [ ] **Step 1: Write Domain Tests**
  Create unit tests in `Tests/DomainTests/MultiCamTypesTests.swift` verifying `MultiCamSlot`, `CompositeLayout`, `PiPPosition`, `MultiCamState`, and `MultiCamError` initialization, serialization/codable, error descriptions, and hashable conformance.

- [ ] **Step 2: Implement Domain Models & Errors**
  Create `Sources/Domain/MultiCamTypes.swift`, `Sources/Domain/MultiCamProtocols.swift`, and `Sources/Domain/MultiCamError.swift`.

- [ ] **Step 3: Update Package.swift**
  Add `MultiCam` library product, `MultiCam` target (dependent on `Domain`), and `MultiCamTests` target to `Package.swift`.

- [ ] **Step 4: Commit**
  ```bash
  git add Package.swift Sources/Domain/ Tests/DomainTests/
  git commit -m "feat(domain): add MultiCam domain types, protocols, and error models"
  ```

---

### Task 2: MultiCam Capability Detection & Hardware Cost Validation

**Files:**
- Create: `Sources/MultiCam/MultiCamCapabilityDetector.swift`
- Create: `Tests/MultiCamTests/MultiCamCapabilityTests.swift`

**Interfaces:**
- Consumes: `CameraDevice`, `CaptureFormat`, `MultiCamDeviceCombination`, `MultiCamSlot`, `CameraMode` from `Domain`
- Produces: `MultiCamCapabilityDetector` providing `discoverSupportedCombinations()`, `validateCombination(_:formats:)`, `isMultiCamSupported()`

- [ ] **Step 1: Write Capability Tests**
  Create `Tests/MultiCamTests/MultiCamCapabilityTests.swift` testing dual and triple combination permutations, cost threshold validations ($> 1.0$ rejected, $\le 1.0$ accepted), format multi-cam compatibility filtering, and non-supported fallback checks.

- [ ] **Step 2: Implement MultiCamCapabilityDetector**
  Implement dynamic device pairing, hardwareCost calculations (`AVCaptureDeviceInput.hardwareCost`, `AVCaptureOutput.hardwareCost`), and format validation (`format.isMultiCamSupported`).

- [ ] **Step 3: Commit**
  ```bash
  git add Sources/MultiCam/MultiCamCapabilityDetector.swift Tests/MultiCamTests/MultiCamCapabilityTests.swift
  git commit -m "feat(multicam): implement dynamic multicam capability detector and cost budgeting"
  ```

---

### Task 3: Multi-Stream Frame Synchronizer

**Files:**
- Create: `Sources/MultiCam/FrameSynchronizer.swift`
- Create: `Tests/MultiCamTests/FrameSynchronizerTests.swift`

**Interfaces:**
- Consumes: `MultiCamSlot`, `MultiCamVideoFrame` from `Domain`
- Produces: `FrameSynchronizer` actor providing `enqueue(frame:for:)`, `flush()`, `setToleranceWindow(seconds:)`, and synchronized frame dispatching.

- [ ] **Step 1: Write Frame Synchronizer Tests**
  Create `Tests/MultiCamTests/FrameSynchronizerTests.swift` testing synchronous timestamp alignment within tolerance window ($\pm 16.6\text{ ms}$), handling of out-of-order frames, handling of dropped frames on one camera without hanging the pipeline, and jitter measurement.

- [ ] **Step 2: Implement FrameSynchronizer**
  Implement actor-isolated ring-buffer synchronizer with sliding presentation timestamp matching window, configurable max age, and metrics reporting.

- [ ] **Step 3: Commit**
  ```bash
  git add Sources/MultiCam/FrameSynchronizer.swift Tests/MultiCamTests/FrameSynchronizerTests.swift
  git commit -m "feat(multicam): implement time-window frame synchronizer for multicam"
  ```

---

### Task 4: High-Performance Composite Renderer

**Files:**
- Create: `Sources/MultiCam/MultiCamCompositor.swift`
- Create: `Tests/MultiCamTests/MultiCamCompositorTests.swift`

**Interfaces:**
- Consumes: `CompositeLayout`, `PiPPosition`, `MultiCamSlot`, `Resolution` from `Domain`
- Produces: `MultiCamCompositor` providing `composite(frames:layout:targetResolution:) async throws -> CVPixelBuffer`

- [ ] **Step 1: Write Compositor Tests**
  Create `Tests/MultiCamTests/MultiCamCompositorTests.swift` testing PiP viewport rect calculations, side-by-side split math, 3-grid transformations, aspect ratio preserving crops, and pixel buffer pool recycling.

- [ ] **Step 2: Implement MultiCamCompositor**
  Implement Metal / CoreImage (`CIContext`) compositor with `CVPixelBufferPool`, supporting PiP, Side-by-Side, 3-split, and 3-grid layouts without converting to `UIImage`.

- [ ] **Step 3: Commit**
  ```bash
  git add Sources/MultiCam/MultiCamCompositor.swift Tests/MultiCamTests/MultiCamCompositorTests.swift
  git commit -m "feat(multicam): implement metal/coreimage multicam compositor with cvpixelbufferpool"
  ```

---

### Task 5: Fallback Handler & Diagnostics

**Files:**
- Create: `Sources/MultiCam/MultiCamFallbackHandler.swift`
- Create: `Sources/MultiCam/MultiCamDiagnostics.swift`
- Create: `Tests/MultiCamTests/MultiCamFallbackTests.swift`

**Interfaces:**
- Consumes: `CameraMode`, `MultiCamSlot`, `CameraDevice`, `MultiCamError` from `Domain`
- Produces: `MultiCamFallbackHandler` providing `negotiateFallback(for:availableDevices:)`, `MultiCamDiagnostics` tracking FPS, drop rate, sync jitter, hardware cost.

- [ ] **Step 1: Write Fallback & Diagnostics Tests**
  Create `Tests/MultiCamTests/MultiCamFallbackTests.swift` verifying Triple $\to$ Dual downgrade, Dual $\to$ Single downgrade, unsupported hardware fallback, and diagnostic telemetry calculation.

- [ ] **Step 2: Implement MultiCamFallbackHandler & MultiCamDiagnostics**
  Implement fallback decision tree with reason codes and thread-safe diagnostic counter collection.

- [ ] **Step 3: Commit**
  ```bash
  git add Sources/MultiCam/MultiCamFallbackHandler.swift Sources/MultiCam/MultiCamDiagnostics.swift Tests/MultiCamTests/MultiCamFallbackTests.swift
  git commit -m "feat(multicam): implement multicam fallback handler and telemetry diagnostics"
  ```

---

### Task 6: Actor-Isolated MultiCamEngine & Capture Delegate

**Files:**
- Create: `Sources/MultiCam/MultiCamCaptureDelegate.swift`
- Create: `Sources/MultiCam/MultiCamEngine.swift`
- Create: `Sources/MultiCam/MultiCamEngine+Configuration.swift`
- Create: `Tests/MultiCamTests/MultiCamEngineTests.swift`

**Interfaces:**
- Consumes: `MultiCamControlling`, `MultiCamCapabilityProviding`, `MultiCamState`, `MultiCamConfiguration`, `FrameSynchronizer`, `MultiCamCompositor`, `MultiCamCapabilityDetector`, `MultiCamFallbackHandler`
- Produces: `MultiCamEngine` actor conforming to `MultiCamControlling`, `MultiCamCapabilityProviding`, publishing `independentFrames` and `compositeFrames`.

- [ ] **Step 1: Implement MultiCamCaptureDelegate**
  Implement dedicated `AVCaptureVideoDataOutputSampleBufferDelegate` tagged with `MultiCamSlot` and serial dispatch queue per slot.

- [ ] **Step 2: Implement MultiCamEngine & Configuration Extension**
  Implement `MultiCamEngine` actor owning `AVCaptureMultiCamSession`, configuring inputs/outputs per slot, starting/stopping capture, switching layouts, managing independent vs. composite stream generation, and handling session interruptions.

- [ ] **Step 3: Write MultiCamEngine Unit Tests**
  Create `Tests/MultiCamTests/MultiCamEngineTests.swift` testing engine lifecycle, configuration validation, stream initialization, and state transitions.

- [ ] **Step 4: Commit**
  ```bash
  git add Sources/MultiCam/ Tests/MultiCamTests/
  git commit -m "feat(multicam): implement actor-isolated MultiCamEngine and capture delegates"
  ```

---

### Task 7: Full Verification, Documentation & MULTICAM_REPORT.md

**Files:**
- Create: `docs/agents/MULTICAM_REPORT.md`

- [ ] **Step 1: Comprehensive Code & Concurrency Review**
  Verify Swift 6 strict concurrency, `@Sendable` closures, actor boundaries, and no compilation warnings.

- [ ] **Step 2: Write MULTICAM_REPORT.md**
  Write complete report covering architecture, dynamic capability discovery, dual/triple support, synchronization, compositor benchmarks, fallback policies, and test results.

- [ ] **Step 3: Commit**
  ```bash
  git add docs/agents/MULTICAM_REPORT.md
  git commit -m "docs: add comprehensive MultiCam subsystem report"
  ```
