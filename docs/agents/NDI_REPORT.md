# TamaNDI — NDI Subsystem Implementation & SDK Status Report

> **Author**: Principal Engineer / NDI Integration Specialist  
> **Subsystem**: NDI (`Sources/NDI/`, `Sources/Domain/`)  
> **Date**: 2026-08-28  
> **Status**: Abstraction & Mock Layer Completed; Physical SDK Integration Blocked  

---

## 1. Executive Summary & SDK Inspection

In accordance with [AGENTS.md](file:///c:/Users/Tama/Desktop/NDI-camera/AGENTS.md) and [prompts/04_NDI.md](file:///c:/Users/Tama/Desktop/NDI-camera/prompts/04_NDI.md), a complete inspection of the project workspace was performed prior to code implementation.

### 1.1 SDK Pre-Implementation Inspection Results

| Inspection Item | Result | Impact & Compliance Action |
|---|---|---|
| **1. Locate `Vendor/NDI/`** | ❌ **Directory Not Found** | No physical headers, binaries, or xcframeworks are present in the repository. |
| **2. Inspect C Headers** | ❌ **Headers Missing** | `Processing.NDI.Lib.h`, `Processing.NDI.structs.h`, and `Processing.NDI.utilities.h` are not available locally. |
| **3. Inspect Module Maps** | ❌ **Module Map Missing** | No Clang module map or Swift bridge headers present for NDI. |
| **4. Swift Interoperability** | ⚠️ **Deferred** | Direct C interop with `NDIlib_v5` C pointers cannot be compiled without local headers. |
| **5. SDK Version** | ❌ **Unspecified** | N/A (Awaiting vendored SDK from Vizrt). |
| **6. Sender APIs** | 📋 **Protocol-Abstracted** | Implemented `NDIBackend` abstraction matching standard `NDIlib_send_create_v2`, `NDIlib_send_send_video_v2`, `NDIlib_send_send_audio_v2`, and `NDIlib_send_destroy`. |
| **7. Supported Video Formats** | 📋 **Abstracted** | `.bgra`, `.nv12`, `.uyvy`, `.p216` (16-bit HDR) configured in `NDIVideoFormat`. |
| **8. Supported Audio Formats** | 📋 **Abstracted** | Linear PCM 48kHz / 44.1kHz stereo/mono floating point audio configured in `NDIConfiguration`. |
| **9. Metadata & Tally APIs** | 📋 **Abstracted** | Supported via `NDIMetadata` (XML payloads) and `NDITally` (`inProgram`, `inPreview`). |
| **10. Thread Safety** | 🛡️ **Enforced** | Strict Swift 6 Concurrency with actor isolation (`NDISender`, `NDIVideoSender`, `NDIAudioSender`, `MockNDIBackend`). |

---

## 2. Hard Blocker Declaration

> [!CAUTION]
> **EXACT BLOCKER**: The NDI iOS SDK (`.xcframework`) is proprietary software owned by Vizrt and must be licensed/downloaded directly by the developer from Vizrt/NewTek and placed into `Vendor/NDI/`.

In strict adherence to the project rules:
- **NO NDI C APIs were invented or guessed.**
- **NO fake NDI networking sockets, fake mDNS beacons, or fake binary packets were implemented.**
- A protocol boundary (`NDIBackend`) and full-fidelity `MockNDIBackend` were created to allow the entire application, UI, camera pipelines, multi-cam composite renderers, and diagnostic systems to be built, tested, and previewed without compile errors.

---

## 3. Architecture & Implemented Components

```
                                  ┌───────────────────────────┐
                                  │         NDISender         │
                                  │      (Actor Isolation)    │
                                  └─────────────┬─────────────┘
                                                │
                     ┌──────────────────────────┴─────────────────────────┐
                     ▼                                                    ▼
           ┌──────────────────┐ (Non-blocking drop queue)       ┌──────────────────┐
           │  NDIVideoSender  │                                 │  NDIAudioSender  │
           └────────┬─────────┘                                 └────────┬─────────┘
                    │                                                    │
                    └──────────────────────────┬─────────────────────────┘
                                               ▼
                                   ┌───────────────────────┐
                                   │  «protocol NDIBackend» │
                                   └───────────┬───────────┘
                                               │
                         ┌─────────────────────┴─────────────────────┐
                         ▼                                           ▼
             ┌───────────────────────┐                   ┌───────────────────────┐
             │    MockNDIBackend     │                   │     RealNDIBackend    │
             │(Testing & Diagnostics)│                   │(When SDK is provided) │
             └───────────────────────┘                   └───────────────────────┘
```

### 3.1 Domain Layer (`Sources/Domain/`)
- [`NDIConfiguration.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Sources/Domain/NDIConfiguration.swift): Source name, NDI discovery groups, target resolution, frame rate, audio sample rate, video format, and clocking flags.
- [`NDITally.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Sources/Domain/NDIMetadata.swift): Program (on-air / red) and Preview (cue / green) tally indicators.
- [`NDIMetadata.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Sources/Domain/NDIMetadata.swift): XML metadata string payload and microsecond timestamps.
- [`NDIStats.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Sources/Domain/NDIStats.swift): Sent video frames, dropped video frames, sent audio packets, bitrate (Mbps), actual sender FPS, and connected receivers count.
- [`NDIProtocols.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Sources/Domain/NDIProtocols.swift): `NDIBackend` and `NDISending` protocol boundaries.
- [`NDIError.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Sources/Domain/NDIError.swift): Strongly-typed localized errors (`backendUnavailable`, `senderCreationFailed`, `videoSendFailed`, `queueOverflow`, etc.).

### 3.2 NDI Layer (`Sources/NDI/`)
- [`MockNDIBackend.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Sources/NDI/MockNDIBackend.swift): Actor-isolated mock runtime recording frame counts, presentation timestamps, audio buffers, metadata history, and tally state simulation for automated tests.
- [`NDIVideoSender.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Sources/NDI/NDIVideoSender.swift): Bounded queue manager (`maxQueueDepth: 2`) enforcing non-blocking backpressure: drops oldest uncompressed frames when network or backend encoding latency increases, preventing camera capture queues from stalling.
- [`NDIAudioSender.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Sources/NDI/NDIAudioSender.swift): Audio ingestion worker routing linear PCM buffers asynchronously.
- [`NDIStatisticsCollector.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Sources/NDI/NDIStatisticsCollector.swift): Rolling FPS and bitrate calculator.
- [`NDISender.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Sources/NDI/NDISender.swift): Actor conforming to `NDISending`, orchestrating start/stop lifecycle, configuration changes, video/audio routing, tally queries, and telemetry snapshots.

---

## 4. Test Verification Summary

| Test Suite | File | What Was Tested |
|---|---|---|
| **NDI Domain Types** | [`NDITypesTests.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Tests/DomainTests/NDITypesTests.swift) | Configuration defaults, Codable round-trips for NDIConfiguration, NDITally, NDIMetadata, NDIStats, and localized error descriptions. |
| **Mock Backend** | [`MockNDIBackendTests.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Tests/NDITests/MockNDIBackendTests.swift) | Backend initialization, sender creation/destruction, sample buffer submission, tally state manipulation, and metadata recording. |
| **Video Backpressure** | [`NDIVideoSenderTests.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Tests/NDITests/NDIVideoSenderTests.swift) | Normal video delivery and frame dropping under simulated slow backend latency (100ms/frame). |
| **Audio Ingestion** | [`NDIAudioSenderTests.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Tests/NDITests/NDIAudioSenderTests.swift) | Linear PCM audio buffer submission to the backend. |
| **Telemetry Statistics** | [`NDIStatsTests.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Tests/NDITests/NDIStatsTests.swift) | Rolling actual FPS calculation, bitrate accumulation, tally update tracking, and reset verification. |
| **NDISender Lifecycle** | [`NDISenderTests.swift`](file:///c:/Users/Tama/Desktop/NDI-camera/Tests/NDITests/NDISenderTests.swift) | Broadcast start/stop state transitions, video frame routing, idle error rejection, and tally queries. |

---

## 5. Next Steps: Physical NDI SDK Integration Guide

When the official Vizrt NDI SDK for iOS is obtained:

1. **Place SDK**: Copy `NDIlib.xcframework` (or `NDI.framework`) into `Vendor/NDI/`.
2. **Add Header Search Path & Linker Settings**: In `Package.swift`, add `.cSettings([.headerSearchPath("../../Vendor/NDI/include")])` or link the binary target.
3. **Implement Real Backend (`RealNDIBackend.swift`)**:
   - Call `NDIlib_initialize()`.
   - Call `NDIlib_send_create()` passing `NDIConfiguration.sourceName` and groups.
   - Convert `CMSampleBuffer` to `NDIlib_video_frame_v2_t` using `CVPixelBufferGetBaseAddress`.
   - Convert PCM audio buffers to `NDIlib_audio_frame_v3_t`.
   - Call `NDIlib_send_send_video_v2()` and `NDIlib_send_send_audio_v3()`.
   - Call `NDIlib_send_get_tally()` to query hardware tally.
4. **Conditional Compilation**: In app initialization:
   ```swift
   #if canImport(NDILib)
       let backend = RealNDIBackend()
   #else
       let backend = MockNDIBackend()
   #endif
   let sender = NDISender(backend: backend)
   ```
