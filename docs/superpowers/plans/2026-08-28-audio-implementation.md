# Audio Subsystem Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a production-grade, actor-isolated Audio subsystem for TamaNDI iOS with dynamic microphone discovery, gain, mute, sample rate / channel controls, interruption handling, route change recovery, audio synchronization, and NDI-ready stream output.

**Architecture:** Actor-isolated `AudioEngine` orchestrating `AVAudioSession` configuration, dynamic `AVAudioSessionPortDescription` discovery, real-time `AVAudioPCMBuffer` capture via `AVAudioEngine` input tap, high-performance DSP (software gain, mute silence injection, and peak/RMS dBFS metering), `AVAudioTime` to `CMTime` synchronization, `CMSampleBuffer` conversion, and frame streaming via `AsyncStream<AudioFrame>` without main-thread blocking.

**Tech Stack:** Swift 6 (Strict Concurrency), iOS 18+, AVFoundation, AVAudioSession, CoreMedia, CoreAudio, Swift Testing (`Testing`).

## Global Constraints

- Platform: iOS 18+, Swift 6, Swift Testing
- Concurrency: Strict Swift 6 Sendable conformance, actor isolation for mutable state, zero main-thread audio processing
- Dynamic Discovery: All microphone ports, polar patterns, and sample rates must be queried dynamically; never hardcode port availability
- Audio Stability: Muting must output zeroed audio samples with unbroken timestamps to preserve NDI synchronization
- Decoupling: Do not implement NDI encoding directly; expose clean protocol boundaries (`AudioControlling`, `AudioCapabilityProviding`, `AudioFrameConsuming`) and `AsyncStream<AudioFrame>`.

---

### Task 1: Domain Models, Protocols & Package.swift Setup

**Files:**
- Create: `Sources/Domain/AudioDevice.swift`
- Create: `Sources/Domain/AudioFormat.swift`
- Create: `Sources/Domain/AudioLevel.swift`
- Create: `Sources/Domain/AudioProtocols.swift`
- Create: `Sources/Domain/AudioError.swift`
- Modify: `Package.swift`
- Create: `Tests/DomainTests/AudioTypesTests.swift`

**Interfaces:**
- Produces: `AudioInputDevice`, `AudioPortType`, `AudioDataSource`, `AudioOrientation`, `AudioPolarPattern`, `AudioSampleRate`, `AudioChannelLayout`, `AudioState`, `AudioLevelsSnapshot`, `AudioFrame`, `AudioControlling`, `AudioCapabilityProviding`, `AudioFrameConsuming`, `AudioError`.

- [ ] **Step 1: Write the failing unit tests in `Tests/DomainTests/AudioTypesTests.swift`**
- [ ] **Step 2: Implement Domain models (`AudioDevice.swift`, `AudioFormat.swift`, `AudioLevel.swift`, `AudioProtocols.swift`, `AudioError.swift`)**
- [ ] **Step 3: Update `Package.swift` to add `Audio` library & target and `AudioTests` testTarget**
- [ ] **Step 4: Verify test suite structure and syntax**
- [ ] **Step 5: Commit changes (`feat(domain): add audio subsystem domain types and protocols`)**

---

### Task 2: Audio DSP Processor & Metering

**Files:**
- Create: `Sources/Audio/AudioDSPProcessor.swift`
- Create: `Tests/AudioTests/AudioDSPProcessorTests.swift`

**Interfaces:**
- Consumes: `AudioLevelsSnapshot`, `AudioState`
- Produces: `AudioDSPProcessor` (`applyGainAndMute`, `calculateLevels`)

- [ ] **Step 1: Write unit tests in `Tests/AudioTests/AudioDSPProcessorTests.swift`**
- [ ] **Step 2: Implement `AudioDSPProcessor.swift`**
- [ ] **Step 3: Verify tests for gain scaling, mute silence injection, and peak/RMS dBFS computation**
- [ ] **Step 4: Commit changes (`feat(audio): implement AudioDSPProcessor for gain, mute and dBFS metering`)**

---

### Task 3: Audio Time Synchronization & CMSampleBuffer Converter

**Files:**
- Create: `Sources/Audio/AudioTimeSynchronizer.swift`
- Create: `Sources/Audio/AudioBufferConverter.swift`
- Create: `Tests/AudioTests/AudioTimeSynchronizerTests.swift`

**Interfaces:**
- Consumes: `AudioFrame`, `CMSampleBuffer`, `AVAudioPCMBuffer`
- Produces: `AudioTimeSynchronizer`, `AudioBufferConverter`

- [ ] **Step 1: Write unit tests in `Tests/AudioTests/AudioTimeSynchronizerTests.swift`**
- [ ] **Step 2: Implement `AudioTimeSynchronizer.swift` and `AudioBufferConverter.swift`**
- [ ] **Step 3: Verify timecode generation, presentation timestamp conversion, and sample buffer creation**
- [ ] **Step 4: Commit changes (`feat(audio): implement AudioTimeSynchronizer and AudioBufferConverter`)**

---

### Task 4: Dynamic Audio Route & Device Discovery

**Files:**
- Create: `Sources/Audio/AudioRouteDiscoverer.swift`
- Create: `Tests/AudioTests/AudioRouteDiscovererTests.swift`

**Interfaces:**
- Consumes: `AudioInputDevice`, `AudioPortType`, `AudioDataSource`, `AVAudioSessionPortDescription`
- Produces: `AudioRouteDiscoverer` (`discoverInputs`, `mapPort`, `mapDataSource`, `mapPolarPattern`)

- [ ] **Step 1: Write unit tests in `Tests/AudioTests/AudioRouteDiscovererTests.swift`**
- [ ] **Step 2: Implement `AudioRouteDiscoverer.swift`**
- [ ] **Step 3: Verify port classification (built-in, USB, Bluetooth HFP/A2DP/LE) and polar pattern mappings**
- [ ] **Step 4: Commit changes (`feat(audio): implement dynamic AudioRouteDiscoverer`)**

---

### Task 5: Audio Session Management & Interruption Handling

**Files:**
- Create: `Sources/Audio/AudioSessionManager.swift`
- Create: `Sources/Audio/AudioCapturePipeline.swift`

**Interfaces:**
- Consumes: `AVAudioSession`, `AudioError`, `AudioState`, `AudioInputDevice`
- Produces: `AudioSessionManager`, `AudioCapturePipeline`

- [ ] **Step 1: Implement `AudioSessionManager.swift` with category/mode configuration, interruption handlers, and route change observers**
- [ ] **Step 2: Implement `AudioCapturePipeline.swift` with `AVAudioEngine` input node tap, DSP processing, and frame generation**
- [ ] **Step 3: Commit changes (`feat(audio): implement AudioSessionManager and AudioCapturePipeline`)**

---

### Task 6: AudioEngine Actor Orchestration & State Management

**Files:**
- Create: `Sources/Audio/AudioEngine.swift`
- Create: `Tests/AudioTests/AudioEngineTests.swift`

**Interfaces:**
- Consumes: `AudioControlling`, `AudioCapabilityProviding`, `AudioSessionManager`, `AudioCapturePipeline`
- Produces: `AudioEngine` actor conforming to `AudioControlling` and `AudioCapabilityProviding`

- [ ] **Step 1: Write unit tests in `Tests/AudioTests/AudioEngineTests.swift`**
- [ ] **Step 2: Implement `AudioEngine.swift` actor**
- [ ] **Step 3: Verify actor state transitions, gain/mute controls, device selection, and `audioFrames` AsyncStream**
- [ ] **Step 4: Commit changes (`feat(audio): implement AudioEngine actor orchestrator`)**

---

### Task 7: Verification, Documentation & Final Report

**Files:**
- Create: `docs/agents/AUDIO_REPORT.md`

- [ ] **Step 1: Run comprehensive verification across all test suites**
- [ ] **Step 2: Create `docs/agents/AUDIO_REPORT.md` with complete architecture, dynamic discovery documentation, and NDI integration guides**
- [ ] **Step 3: Commit final report (`docs(audio): add AUDIO_REPORT.md`)**
