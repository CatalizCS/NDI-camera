# TamaNDI — Audio Subsystem Specification

- **Date**: 2026-08-28
- **Author**: Antigravity Assistant & Audio Integration Specialist
- **Status**: Approved Design Spec
- **Target Platform**: iOS 18+, Swift 6, AVFoundation, AVAudioSession, CoreMedia, CoreAudio

---

## 1. Overview & Objectives

The Audio Subsystem provides a professional, broadcast-grade audio capture, routing, DSP (gain/mute/metering), and synchronization engine for TamaNDI.

### Core Objectives:
1. **Dynamic Route & Microphone Discovery**: Discover and classify built-in microphones (with orientation/polar pattern data sources), external USB audio interfaces, and Bluetooth devices (HFP/A2DP/LE) dynamically at runtime. Never hardcode or assume port availability.
2. **Audio Session Lifecycle & Robustness**: Configure `AVAudioSession` (.playAndRecord, .videoRecording / .measurement mode) and handle route changes, system interruptions (e.g. incoming calls, alarms), and media service resets gracefully.
3. **Gain & Mute Controls**: Hardware input gain adjustment when supported (`isInputGainSettable`), seamlessly falling back to high-precision software digital gain, along with silence-injecting mute to maintain clock synchronization.
4. **Format & Channel Management**: Support standard broadcast sample rates (48 kHz default, 44.1 kHz fallback) and flexible channel configurations (Mono, Stereo, Multichannel).
5. **Time Synchronization & NDI Hand-off**: Generate sample-accurate `AudioFrame` structures and `CMSampleBuffer` instances with presentation timestamps (`CMTime`) and microsecond timecodes referenced to system host time (`mach_absolute_time`), exposed via clean protocol interfaces and `AsyncStream<AudioFrame>` for NDI transmission.

---

## 2. Architecture & File Structure

```
Sources/
├── Domain/
│   ├── AudioDevice.swift          # AudioInputDevice, AudioPortType, AudioDataSource, AudioOrientation, PolarPattern
│   ├── AudioFormat.swift          # AudioSampleRate, AudioChannelLayout, AudioConfiguration, AudioBitDepth
│   ├── AudioLevel.swift           # AudioLevelsSnapshot, Peak/RMS dBFS metering values
│   ├── AudioProtocols.swift       # AudioControlling, AudioCapabilityProviding, AudioFrameConsuming, AudioStreaming
│   └── AudioError.swift           # Strongly-typed localized audio errors
└── Audio/
    ├── AudioEngine.swift          # Actor-isolated orchestrator conforming to AudioControlling & AudioCapabilityProviding
    ├── AudioSessionManager.swift  # AVAudioSession configuration, category/mode setup, route change & interruption handling
    ├── AudioRouteDiscoverer.swift # Discovers built-in mics, USB devices, Bluetooth endpoints & data sources
    ├── AudioCapturePipeline.swift # AVAudioEngine input node tap, audio buffer processing & queue dispatch
    ├── AudioDSPProcessor.swift    # Software digital gain, mute silence injection, and peak/RMS dBFS level metering
    ├── AudioTimeSynchronizer.swift# Converts audio host time to CMTime and microsecond timecodes
    └── AudioBufferConverter.swift # Constructs CMSampleBuffer from AVAudioPCMBuffer with correct ASBD

Tests/
├── DomainTests/
│   └── AudioTypesTests.swift      # Unit tests for Domain models, Codable conformity, and error descriptions
└── AudioTests/
    ├── AudioDSPProcessorTests.swift     # Tests for digital gain scaling, mute silence, and dBFS metering
    ├── AudioTimeSynchronizerTests.swift # Tests for timestamp calculation and clock stability
    ├── AudioRouteDiscovererTests.swift  # Tests for port type classification and data source mapping
    └── AudioEngineTests.swift           # Tests for actor lifecycle, state transitions, and frame stream delivery
```

---

## 3. Detailed Component Specifications

### 3.1 Domain Layer (`Sources/Domain/`)

- **`AudioInputDevice`**:
  ```swift
  public struct AudioInputDevice: Sendable, Identifiable, Hashable, Codable {
      public let id: String
      public let name: String
      public let portType: AudioPortType
      public let channels: Int
      public let isBuiltIn: Bool
      public let isBluetooth: Bool
      public let isUSB: Bool
      public let availableDataSources: [AudioDataSource]
      public let selectedDataSource: AudioDataSource?
  }
  ```

- **`AudioPortType`**:
  ```swift
  public enum AudioPortType: String, Sendable, Codable, Hashable {
      case builtInMic
      case headsetMic
      case lineIn
      case usbAudio
      case bluetoothHFP
      case bluetoothA2DP
      case bluetoothLE
      case other
  }
  ```

- **`AudioDataSource`**:
  ```swift
  public struct AudioDataSource: Sendable, Identifiable, Hashable, Codable {
      public let id: String
      public let name: String
      public let orientation: AudioOrientation
      public let polarPattern: AudioPolarPattern
  }
  ```

- **`AudioState`**:
  ```swift
  public struct AudioState: Sendable, Hashable {
      public let isRunning: Bool
      public let isMuted: Bool
      public let gain: Float
      public let isHardwareGain: Bool
      public let selectedDevice: AudioInputDevice?
      public let selectedDataSource: AudioDataSource?
      public let sampleRate: AudioSampleRate
      public let channelLayout: AudioChannelLayout
      public let sessionState: StreamState
  }
  ```

- **`AudioFrame`**:
  ```swift
  public struct AudioFrame: Sendable {
      public let sampleBuffer: CMSampleBuffer
      public let timestamp: CMTime
      public let timecodeMicros: Int64
      public let sampleRate: Double
      public let channelCount: Int
      public let frameCount: Int
  }
  ```

- **`AudioControlling` & `AudioCapabilityProviding` Protocols**:
  Provide a complete boundary between the UI/NDI layers and the audio engine.

### 3.2 Audio Layer (`Sources/Audio/`)

- **`AudioEngine` (Actor)**:
  - Central actor managing capture start/stop, input port switching, and state publishing.
  - Exposes `nonisolated let audioFrames: AsyncStream<AudioFrame>` for continuous frame streaming.
  - Implements `AudioControlling` and `AudioCapabilityProviding`.

- **`AudioSessionManager`**:
  - Sets up `AVAudioSession` with `.playAndRecord`, `.videoRecording` or `.measurement` modes, and options `[.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]`.
  - Subscribes to:
    - `AVAudioSession.interruptionNotification` (pauses and recovers audio capture cleanly).
    - `AVAudioSession.routeChangeNotification` (re-evaluates available devices, preserves selected routes or falls back safely).
    - `AVAudioSession.mediaServicesWereResetNotification` (re-initializes internal audio graph).

- **`AudioRouteDiscoverer`**:
  - Dynamically inspects `AVAudioSession.sharedInstance().availableInputs` and `currentRoute.inputs`.
  - Extracts supported data sources and polar patterns (Omnidirectional, Subcardioid, Cardioid, Supercardioid, Hypercardioid, BiDirectional) when exposed by iOS.

- **`AudioDSPProcessor`**:
  - Applies software gain multiplier ($S_{out} = S_{in} \times \text{gain}$) when hardware gain is not available.
  - Injects silence (clearing buffer memory to $0.0$) when muted, maintaining unbroken timestamp continuity for downstream NDI streams.
  - Calculates real-time Peak and RMS dBFS values for multi-channel audio meters.

- **`AudioTimeSynchronizer`**:
  - Maps `AVAudioTime.hostTime` to `CMTime` and calculates microsecond presentation timestamps synchronized with the system mach clock, ensuring alignment with video frames.

- **`AudioBufferConverter`**:
  - Converts `AVAudioPCMBuffer` into standard linear PCM `CMSampleBuffer` with standard `AudioStreamBasicDescription` (Float32 or Int16 LPCM, non-interleaved or interleaved), suitable for NDI ingestion.

---

## 4. Concurrency & Performance Guarantees

1. **Zero Main-Thread Audio Processing**: Audio I/O callbacks run on high-priority audio threads.
2. **Actor State Isolation**: All mutable state is isolated within `AudioEngine` and thread-safe helper structures.
3. **Continuous Clock Stream**: When muted, audio buffers continue to be generated with zeroed samples, preventing receiver buffer starvation or audio clock drift in NDI decoders.
4. **Non-blocking Buffer Forwarding**: Frames are yielded to `AsyncStream<AudioFrame>` with bounded buffering to prevent backpressure stalls.

---

## 5. Testing & Verification Plan

1. **Domain Tests**:
   - Codable serialization and round-trips for all audio domain models.
   - AudioError description verification and Hashable conformance.
2. **DSP Processor Tests**:
   - Gain scaling calculations across varied input amplitudes.
   - Mute behavior (verifies all buffer floats are 0.0).
   - Peak / RMS dBFS calculations against reference sine/silent buffers.
3. **Time Synchronizer Tests**:
   - Host time to `CMTime` conversion accuracy and monotonically increasing timecodes.
4. **Route Discoverer & Mapper Tests**:
   - Port type mapping (`.builtInMic`, `.usbAudio`, `.bluetoothHFP`, etc.).
   - Data source and polar pattern conversion.
5. **AudioEngine Lifecycle Tests**:
   - Start, stop, mute, gain, and device selection state transitions.
