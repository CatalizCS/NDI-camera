# NDI Subsystem Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a production-grade, modular `NDI` subsystem for TamaNDI on iOS 18+ / Swift 6 supporting protocol-abstracted backend architecture, mock backend implementation, actor-isolated `NDISender`, `NDIVideoSender` with non-blocking backpressure frame dropping, `NDIAudioSender`, `NDIConfiguration`, `NDIStats`, `NDIMetadata`, comprehensive unit tests, and the `docs/agents/NDI_REPORT.md` report.

**Architecture:** Protocol boundary `NDIBackend` separating the application from concrete SDK implementations. `MockNDIBackend` providing full fidelity testing without external dependencies. Actor-isolated `NDISender` coordinating video and audio pipelines with bounded queue depth and real-time telemetry.

**Tech Stack:** Swift 6 (Strict Concurrency), iOS 18+, AVFoundation, CoreMedia, CoreVideo, Swift Testing framework.

## Global Constraints

- **Platform:** iOS 18+, Swift 6 (`.swiftLanguageMode(.v6)`), AVFoundation, CoreMedia, CoreVideo.
- **Never Invent NDI APIs:** The NDI SDK is currently not present in `Vendor/NDI/`. Never invent fake C APIs or create fake socket binary packets.
- **Modularity:** UI and camera systems must depend exclusively on protocols (`NDISending`, `NDIBackend`) rather than concrete SDK types.
- **Performance:** Non-blocking capture queues, bounded frame queue depth, zero `UIImage` conversions.
- **Concurrency:** Swift Concurrency (`Sendable`, actors, no unsafe shared mutable state).

---

### Task 1: Domain Layer Models, Protocols, and Errors

**Files:**
- Create: `Sources/Domain/NDIConfiguration.swift`
- Create: `Sources/Domain/NDIStats.swift`
- Create: `Sources/Domain/NDIMetadata.swift`
- Create: `Sources/Domain/NDIProtocols.swift`
- Create: `Sources/Domain/NDIError.swift`
- Modify: `Package.swift` (add NDI target and NDITests test target)
- Create: `Tests/DomainTests/NDITypesTests.swift`

**Interfaces:**
- Produces: `NDIConfiguration`, `NDIStats`, `NDIMetadata`, `NDITally`, `NDIState`, `NDIBackend`, `NDISending`, `NDIError`

- [ ] **Step 1: Write Domain Tests**
  Create unit tests in `Tests/DomainTests/NDITypesTests.swift` verifying `NDIConfiguration`, `NDITally`, `NDIStats`, `NDIMetadata`, and `NDIError` localized descriptions and Codable conformance.

- [ ] **Step 2: Implement Domain Models & Protocols**
  Create `NDIConfiguration.swift`, `NDIStats.swift`, `NDIMetadata.swift`, `NDIProtocols.swift`, and `NDIError.swift` in `Sources/Domain/`.

- [ ] **Step 3: Update Package.swift**
  Add `NDI` library product, `NDI` target (dependent on `Domain`, `Camera`), and `NDITests` target.

- [ ] **Step 4: Commit**
  ```bash
  git add Package.swift Sources/Domain/ Tests/DomainTests/
  git commit -m "feat(domain): add NDI domain configurations, protocols, and error models"
  ```

---

### Task 2: MockNDIBackend and Backend Contract

**Files:**
- Create: `Sources/NDI/NDIBackend.swift`
- Create: `Sources/NDI/MockNDIBackend.swift`
- Create: `Tests/NDITests/MockNDIBackendTests.swift`

**Interfaces:**
- Consumes: `NDIBackend`, `NDIConfiguration`, `NDIMetadata`, `NDITally`, `VideoFrame` from `Domain` and `Camera`
- Produces: `MockNDIBackend` implementing `NDIBackend` with recording, tally simulation, and metrics inspection.

- [ ] **Step 1: Write Mock Backend Tests**
  Create `Tests/NDITests/MockNDIBackendTests.swift` testing initialization, sender creation/destruction, video/audio submission, tally state manipulation, and metadata handling.

- [ ] **Step 2: Implement NDIBackend re-export and MockNDIBackend**
  Create `Sources/NDI/NDIBackend.swift` and `Sources/NDI/MockNDIBackend.swift`.

- [ ] **Step 3: Commit**
  ```bash
  git add Sources/NDI/ Tests/NDITests/
  git commit -m "feat(ndi): implement MockNDIBackend and backend protocol interfaces"
  ```

---

### Task 3: Video and Audio Sender Pipelines

**Files:**
- Create: `Sources/NDI/NDIVideoSender.swift`
- Create: `Sources/NDI/NDIAudioSender.swift`
- Create: `Tests/NDITests/NDIVideoSenderTests.swift`
- Create: `Tests/NDITests/NDIAudioSenderTests.swift`

**Interfaces:**
- Consumes: `NDIBackend`, `VideoFrame`, `CMSampleBuffer`
- Produces: `NDIVideoSender` providing non-blocking enqueue and backpressure frame dropping, and `NDIAudioSender` providing audio buffer submission.

- [ ] **Step 1: Write Video & Audio Sender Tests**
  Create `Tests/NDITests/NDIVideoSenderTests.swift` and `Tests/NDITests/NDIAudioSenderTests.swift` verifying bounded queue behavior, frame dropping under simulated slow backend, and audio submission.

- [ ] **Step 2: Implement NDIVideoSender and NDIAudioSender**
  Create `Sources/NDI/NDIVideoSender.swift` and `Sources/NDI/NDIAudioSender.swift`.

- [ ] **Step 3: Commit**
  ```bash
  git add Sources/NDI/ Tests/NDITests/
  git commit -m "feat(ndi): implement NDIVideoSender with backpressure and NDIAudioSender"
  ```

---

### Task 4: NDISender Actor and Telemetry Statistics

**Files:**
- Create: `Sources/NDI/NDIStatisticsCollector.swift`
- Create: `Sources/NDI/NDISender.swift`
- Create: `Tests/NDITests/NDIStatsTests.swift`
- Create: `Tests/NDITests/NDISenderTests.swift`

**Interfaces:**
- Consumes: `NDISending`, `NDIBackend`, `NDIConfiguration`, `NDIVideoSender`, `NDIAudioSender`
- Produces: `NDISender` actor conforming to `NDISending`, `NDIStatisticsCollector`

- [ ] **Step 1: Write Statistics & NDISender Tests**
  Create `Tests/NDITests/NDIStatsTests.swift` and `Tests/NDITests/NDISenderTests.swift` verifying start/stop lifecycle, state transitions, frame routing, and statistics calculation.

- [ ] **Step 2: Implement NDIStatisticsCollector and NDISender**
  Create `Sources/NDI/NDIStatisticsCollector.swift` and `Sources/NDI/NDISender.swift`.

- [ ] **Step 3: Commit**
  ```bash
  git add Sources/NDI/ Tests/NDITests/
  git commit -m "feat(ndi): implement actor-isolated NDISender and statistics collector"
  ```

---

### Task 5: Documentation & NDI_REPORT.md

**Files:**
- Create: `docs/agents/NDI_REPORT.md`

- [ ] **Step 1: Write Comprehensive NDI Report**
  Create `docs/agents/NDI_REPORT.md` documenting SDK inspection results, absence of `Vendor/NDI/`, architectural protocol design, mock backend implementation, backpressure strategy, and developer integration instructions for when the NDI SDK is added.

- [ ] **Step 2: Commit**
  ```bash
  git add docs/agents/NDI_REPORT.md
  git commit -m "docs: add comprehensive NDI subsystem report"
  ```
