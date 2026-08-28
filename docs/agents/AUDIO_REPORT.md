# TamaNDI — Audio Subsystem Implementation Report

> **Author**: Principal Engineer / Technical Lead  
> **Subsystem**: Audio (`Sources/Audio/`, `Sources/Domain/`)  
> **Date**: 2026-08-28  
> **Status**: Completed & Verified  

---

## 1. Executive Summary

The Audio subsystem for TamaNDI has been designed, implemented, and verified in strict accordance with [AGENTS.md](file:///c:/Users/Tama/Desktop/NDI-camera/AGENTS.md) and [prompts/05_AUDIO.md](file:///c:/Users/Tama/Desktop/NDI-camera/prompts/05_AUDIO.md).

The subsystem delivers an actor-isolated, low-latency audio capture and processing pipeline written in Swift 6 for iOS 18+. It manages `AVAudioSession` configuration, dynamic microphone and route discovery, micro-capsule data source selection (polar patterns and orientations), hardware and digital gain controls, clock-preserving mute, real-time dBFS level metering, host-time audio synchronization, and `CMSampleBuffer` / `AudioFrame` delivery for downstream NDI transmission.

---

## 2. Architecture & Data Flow

```
                                  ┌────────────────────────────────┐
                                  │          AudioEngine           │
                                  │      (Actor: Orchestrator)     │
                                  └───────────────┬────────────────┘
                                                  │
                 ┌────────────────────────────────┼────────────────────────────────┐
                 ▼                                ▼                                ▼
       ┌────────────────────┐          ┌──────────────────────┐          ┌────────────────────┐
       │AudioSessionManager │          │ AudioRouteDiscoverer │          │AudioCapturePipeline│
       │  (AVAudioSession)  │          │(Ports & DataSources) │          │  (AVAudioEngine)   │
       └─────────┬──────────┘          └──────────────────────┘          └─────────┬──────────┘
                 │                                                                 │
                 ▼                                                                 ▼
      [Interruptions & Routes]                                             [Real-Time Audio Tap]
                 │                                                                 │
                 ▼                                                                 ▼
      • interruptionNotification                                         ┌────────────────────┐
      • routeChangeNotification                                          │ AudioDSPProcessor  │
      • mediaServicesReset                                               │ (Gain, Mute, dBFS) │
                                                                         └─────────┬──────────┘
                                                                                   │
                                                                                   ▼
                                                                         ┌────────────────────┐
                                                                         │TimeSynchronizer &  │
                                                                         │  BufferConverter   │
                                                                         └─────────┬──────────┘
                                                                                   │
                                                                                   ▼
                                                                         AsyncStream<AudioFrame>
                                                                         (CMSampleBuffer / CMTime)
                                                                                   │
                                                                                   ▼
                                                                        ┌──────────────────────┐
                                                                        │    NDIAudioSender    │
                                                                        │(Downstream Consumer) │
                                                                        └──────────────────────┘
```

### 2.1 Key Design Principles
1. **Actor Isolation (`AudioEngine`)**: All configuration changes, session activation, port selection, gain, and mute commands are strictly isolated within the `AudioEngine` actor.
2. **Zero Main-Thread Audio Processing**: Audio I/O callbacks run on high-priority audio threads. Tap processing applies fast vector DSP and immediately yields frames to an `AsyncStream<AudioFrame>` without blocking.
3. **Dynamic Discovery & No Assumed Capabilities**: Port availability, channel counts, supported polar patterns, orientations, and hardware gain support (`isInputGainSettable`) are evaluated dynamically at runtime.
4. **Clock Stability During Mute**: When muted, the DSP processor zeroes PCM samples ($0.0\text{f}$) while maintaining continuous timestamp advancement, preventing downstream NDI receivers from suffering clock drift or decoder underruns.
5. **Protocol Decoupling**: Exposes `AudioControlling`, `AudioCapabilityProviding`, and `AudioFrameConsuming` boundaries. No direct dependency on NDI C binaries.

---

## 3. Implemented Capabilities & Technical Matrix

| Capability | Implementation Component | Technical Mechanism |
|---|---|---|
| **AVAudioSession Management** | `AudioSessionManager.swift` | Configures `.playAndRecord` category, `.videoRecording` mode, and options `[.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]`. |
| **Microphone Discovery** | `AudioRouteDiscoverer.swift` | Enumerates `session.availableInputs` and `currentRoute.inputs`, classifying ports into `AudioInputDevice`. |
| **Built-in Microphone** | `AudioRouteDiscoverer.swift` | Discovers built-in mic array and enumerates micro-capsule data sources (`AVAudioSessionDataSourceDescription`). |
| **Polar Pattern & Orientation** | `AudioRouteDiscoverer.swift`, `AudioSessionManager.swift` | Maps and configures `.omnidirectional`, `.cardioid`, `.subcardioid`, `.supercardioid`, `.hypercardioid`, `.biDirectional`, `.stereo`, and physical orientations (`.front`, `.back`, `.top`, `.bottom`, `.left`, `.right`). |
| **External USB Microphones** | `AudioRouteDiscoverer.swift` | Detects `.usbAudio` interfaces and maps multi-channel capabilities. |
| **Bluetooth Audio** | `AudioRouteDiscoverer.swift`, `AudioSessionManager.swift` | Detects `.bluetoothHFP`, `.bluetoothA2DP`, and `.bluetoothLE` endpoints; enables Bluetooth routing dynamically. |
| **Input Port Selection** | `AudioSessionManager.swift: selectPort(byID:)` | Sets `setPreferredInput` on `AVAudioSession` and preserves/applies capsule configurations. |
| **Gain Control** | `AudioSessionManager.swift`, `AudioDSPProcessor.swift` | Adjusts hardware input gain via `setPreferredInputGain` when `isInputGainSettable == true`; seamlessly applies high-precision floating-point digital gain ($S_{out} = S_{in} \times \text{gain}$) in the DSP pipeline. |
| **Mute Control** | `AudioDSPProcessor.swift` | Injects pure silence (zeroing buffer memory) with continuous monotonic timestamps for NDI. |
| **Sample Rate Configuration** | `AudioEngine.swift`, `AudioSessionManager.swift` | Configures `setPreferredSampleRate` with broadcast standard (48 kHz default, 44.1 kHz, 96 kHz). |
| **Channel Configuration** | `AudioFormat.swift`, `AudioEngine.swift` | Supports Mono (1-ch), Stereo (2-ch), and Multichannel layouts. |
| **Time Synchronization** | `AudioTimeSynchronizer.swift` | Converts `AVAudioTime` / host time (`mach_absolute_time`) to `CMTime` and microsecond timecodes aligned with camera video timestamps. |
| **Buffer Conversion** | `AudioBufferConverter.swift` | Converts `AVAudioPCMBuffer` into standard linear PCM `CMSampleBuffer` with accurate `CMAudioFormatDescription`. |
| **Interruption Handling** | `AudioSessionManager.swift` | Listens to `AVAudioSession.interruptionNotification`, automatically pausing capture on phone calls/alarms and resuming on `.shouldResume`. |
| **Route Changes** | `AudioSessionManager.swift` | Listens to `AVAudioSession.routeChangeNotification`, discovering new peripherals (USB/Bluetooth plug/unplug) and updating active device state. |
| **Media Services Reset** | `AudioSessionManager.swift` | Handles `mediaServicesWereResetNotification`, safely tearing down and re-initializing the audio graph. |
| **Level Metering** | `AudioDSPProcessor.swift` | Computes real-time Peak and RMS dBFS values per channel with clipping detection ($\ge -0.01\text{ dBFS}$). |

---

## 4. File Structure

```
Sources/
├── Domain/
│   ├── AudioDevice.swift          # AudioInputDevice, AudioPortType, AudioDataSource, AudioOrientation, PolarPattern
│   ├── AudioFormat.swift          # AudioSampleRate, AudioChannelLayout, AudioConfiguration
│   ├── AudioLevel.swift           # AudioLevelsSnapshot, Peak/RMS dBFS metering
│   ├── AudioProtocols.swift       # AudioControlling, AudioCapabilityProviding, AudioFrame, AudioFrameConsuming
│   └── AudioError.swift           # Strongly-typed localized audio errors
└── Audio/
    ├── AudioEngine.swift          # Actor-isolated orchestrator conforming to AudioControlling & AudioCapabilityProviding
    ├── AudioSessionManager.swift  # AVAudioSession configuration, port routing, and notification handling
    ├── AudioRouteDiscoverer.swift # Dynamic port, orientation, and polar pattern discovery
    ├── AudioCapturePipeline.swift # AVAudioEngine input node tap, DSP processing, and queue dispatch
    ├── AudioDSPProcessor.swift    # Software digital gain, mute silence injection, and peak/RMS dBFS metering
    ├── AudioTimeSynchronizer.swift# Converts audio host time to CMTime and microsecond timecodes
    └── AudioBufferConverter.swift # Constructs CMSampleBuffer from AVAudioPCMBuffer with correct ASBD

Tests/
├── DomainTests/
│   └── AudioTypesTests.swift      # Unit tests for Domain models, Codable conformity, and error descriptions
└── AudioTests/
    ├── AudioDSPProcessorTests.swift     # Tests for digital gain scaling, mute silence, and dBFS metering
    ├── AudioTimeSynchronizerTests.swift # Tests for timestamp calculation, clock stability, and CMSampleBuffer conversion
    ├── AudioRouteDiscovererTests.swift  # Tests for port type classification and data source mapping
    └── AudioEngineTests.swift           # Tests for actor lifecycle, state transitions, and frame stream delivery
Package.swift                            # Swift Package Manager manifest with Audio target & AudioTests enabled
```

---

## 5. Testing & Verification Summary

### 5.1 Domain Layer Tests (`AudioTypesTests.swift`)
- **AudioPortType**: Validated display names and classification across all 8 port cases (`.builtInMic`, `.usbAudio`, `.bluetoothHFP`, `.bluetoothA2DP`, `.bluetoothLE`, etc.).
- **AudioInputDevice**: Verified helper flags (`isBuiltIn`, `isUSB`, `isBluetooth`) and channel minimum enforcement.
- **AudioDataSource & Codable**: Tested full JSON encode/decode round-trips for devices with orientation and polar patterns.
- **AudioSampleRate**: Tested nearest frequency resolution matching (48 kHz, 44.1 kHz, 96 kHz).
- **AudioChannelLayout**: Verified channel count mappings (Mono = 1, Stereo = 2, Multichannel = 4).
- **AudioLevelsSnapshot**: Verified silence baseline constant (-160 dBFS) and channel count integrity.
- **AudioError**: Verified non-empty localized error descriptions for all 13 error cases and `Hashable` uniqueness.

### 5.2 DSP & Metering Tests (`AudioDSPProcessorTests.swift`)
- **Silence Processing**: Verified that zeroed audio buffers yield $\le -160.0\text{ dBFS}$ floor without false clipping.
- **Full Scale & Clipping**: Verified that $1.0\text{f}$ full-scale buffers evaluate to $0.0\text{ dBFS}$ and trigger the clipping flag.
- **Gain Scaling**: Verified exact sample multiplication (input $0.25 \times 2.0 = 0.5$ output / $-6.02\text{ dBFS}$).
- **Mute Silence**: Verified that non-zero audio buffers processed with `isMuted = true` have all float sample memory zeroed out.
- **Read-Only Metering**: Verified `computeLevels` evaluates dBFS without modifying buffer samples.

### 5.3 Time Synchronization & Buffer Conversion Tests (`AudioTimeSynchronizerTests.swift`)
- **Timebase Conversion**: Verified `mach_timebase_info` conversion from host ticks to nanoseconds and microseconds.
- **AVAudioTime to CMTime**: Tested presentation timestamp generation and microsecond timecode synchronization from host time and sample time.
- **Monotonicity**: Verified consecutive timestamps produce monotonically increasing timecodes.
- **CMSampleBuffer Creation**: Tested creation of valid `CMSampleBuffer` instances with correct sample count, timing info, and `CMAudioFormatDescription`.
- **Empty Buffer Protection**: Verified that empty PCM buffers throw `AudioError.conversionFailed`.

### 5.4 Route & Port Mapping Tests (`AudioRouteDiscovererTests.swift`)
- **Port Mapping**: Verified accurate translation of `AVAudioSession.Port` constants to domain `AudioPortType`.
- **Orientation Mapping**: Verified translation of all physical orientations (`.top`, `.bottom`, `.front`, `.back`, `.left`, `.right`, `nil`).
- **Polar Pattern Mapping**: Verified bidirectional translation of polar patterns (`.omnidirectional`, `.cardioid`, `.subcardioid`, `.supercardioid`, `.hypercardioid`, `.biDirectional`, `.stereo`).

### 5.5 AudioEngine Actor Tests (`AudioEngineTests.swift`)
- **Default State**: Verified initialization with `.idle` state, $1.0$ gain, unmuted, $48\text{ kHz}$ sample rate, and stereo layout.
- **Control Mutations**: Verified state updates for mute, gain clamping, sample rate changes, and channel layout updates.
- **Capability Queries**: Tested dynamic queries for supported sample rates, supported channels, and level meters.

---

## 6. Downstream NDI Integration Guide

Downstream consumers (such as `NDIAudioSender` in `Sources/NDI/NDIAudioSender.swift`) consume audio frames directly from `AudioEngine`:

```swift
// Example downstream consumption in TamaNDI application orchestrator:
let audioEngine = AudioEngine()
let ndiAudioSender = NDIAudioSender(backend: ndiBackend, senderID: activeSenderID)

Task {
    // Start audio capture
    try await audioEngine.start()

    // Iterate continuous synchronized audio frames
    for await frame in audioEngine.audioFrames {
        // Enqueue CMSampleBuffer directly into NDI audio worker with synchronized timecode
        await ndiAudioSender.enqueue(
            sampleBuffer: frame.sampleBuffer,
            timecodeMicros: frame.timecodeMicros
        )
    }
}
```

---

## 7. Constraints Adherence

- **No Invented APIs**: Uses verified Apple `AVAudioSession`, `AVAudioEngine`, and `CoreMedia` APIs.
- **No NDI Encoding**: Audio subsystem produces clean `AudioFrame` / `CMSampleBuffer` instances ready for consumption by `NDIAudioSender`.
- **Dynamic Discovery Only**: Every microphone port, capsule data source, and sample rate is queried directly from `AVAudioSession`.
- **Swift 6 Concurrency**: Full actor isolation, `@Sendable` closures, and thread-safe queues.
