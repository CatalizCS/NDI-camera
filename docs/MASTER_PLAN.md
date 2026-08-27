# TamaNDI — Master Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal**: Build a production-quality native iOS NDI camera application with multi-camera support, LAN remote control, and broadcast-grade reliability.

**Architecture**: Modular, protocol-oriented, actor-isolated. 11 distinct layers with explicit dependency direction. NDI behind a backend protocol (Mock initially, Real when SDK is provided). Camera capabilities dynamically discovered. See [ARCHITECTURE.md](file:///c:/Users/Tama/Desktop/NDI-camera/docs/ARCHITECTURE.md).

**Tech Stack**: Swift 6, SwiftUI, AVFoundation, Network.framework, Bonjour, Metal (composition only), os.Logger, os_signpost

## Global Constraints

- iOS 18.0+ deployment target
- Swift 6 with strict concurrency checking enabled from first commit
- No third-party Swift packages — Apple frameworks only
- NDI SDK is **NOT AVAILABLE** — all NDI integration uses `MockNDIBackend` until developer provides SDK
- Never invent NDI APIs — `RealNDIBackend` implementation is BLOCKED (see [RISKS.md R-001](file:///c:/Users/Tama/Desktop/NDI-camera/docs/RISKS.md))
- Never hard-code camera capabilities — all discovered dynamically
- Never process frames on main thread
- Never convert `CVPixelBuffer` to `UIImage` in the capture pipeline
- All model types must be `Sendable`
- Every module must have unit tests
- Every feature must have diagnostics and failure handling

---

## Section 1 — Repository Assessment

### 1.1 Current State

| Aspect | Status |
|---|---|
| Swift source code | ❌ None — greenfield project |
| Xcode project | ❌ Does not exist |
| Vendor/NDI SDK | ❌ Directory missing — NDI BLOCKED |
| Git repository | ❌ Not initialized |
| Prompt specifications | ✅ 15 detailed prompts in `prompts/` |
| Settings schema | ✅ JSON Schema in `schemas/settings.schema.json` |
| Web controller prototype | ✅ HTML/CSS/JS in `web/` |
| Asset icons | ✅ 4 SVG icons in `assets/icons/` |
| API contract sketch | ✅ `docs/API.md` (minimal) |
| Engineering rules | ✅ `AGENTS.md` with clear constraints |

### 1.2 What Exists and Is Usable

1. **Prompt specifications** (`prompts/00` through `prompts/14`) — comprehensive feature specs that define every module. These serve as the source of truth for requirements.
2. **Settings schema** — defines the configuration model. Usable as-is for the `Preset` and `Settings` types.
3. **Web controller prototype** — working HTML/CSS/JS skeleton with REST and WebSocket integration. Can be enhanced in-place.
4. **SVG assets** — usable as SF Symbol alternatives for the iOS UI and web dashboard.
5. **API contract** — minimal but establishes the REST/WebSocket pattern.

### 1.3 What Must Be Created

- Complete Xcode project with Swift Package Manager structure
- All 11 architecture layers with Swift source files
- `NDIBackend` protocol and `MockNDIBackend`
- Test targets with comprehensive coverage
- Documentation: SETUP.md, NDI_SDK_SETUP.md, TROUBLESHOOTING.md
- .gitignore, privacy manifest, Info.plist configurations
- App Store metadata and permission descriptions

---

## Section 2 — Architecture Proposal

> Full details in [ARCHITECTURE.md](file:///c:/Users/Tama/Desktop/NDI-camera/docs/ARCHITECTURE.md)

### 2.1 Layer Summary

| # | Layer | Responsibility | Actor/Isolation |
|---|---|---|---|
| 1 | Domain | Pure value types, protocols | None (Sendable structs/enums) |
| 2 | Diagnostics | Logging, metrics, signposts | `DiagnosticsActor` |
| 3 | Capture | AVCaptureVideoDataOutput delegate, frame delivery | Dedicated serial queue |
| 4 | MultiCam | AVCaptureMultiCamSession, combination validation | Shares CameraSessionActor |
| 5 | Camera | Device discovery, session config, controls | `CameraSessionActor` |
| 6 | Audio | Route discovery, mic selection, audio capture | Dedicated serial queue |
| 7 | NDI | Backend protocol, mock/real sender, backpressure | `NDISenderActor` |
| 8 | WebController | Static HTML/CSS/JS assets | N/A (files) |
| 9 | Remote | HTTP + WebSocket server, Bonjour, pairing | NWListener queue |
| 10 | Persistence | UserDefaults, presets, JSON import/export | `@MainActor` |
| 11 | UI | SwiftUI views, view models, navigation | `@MainActor` |

### 2.2 Key Design Decisions

1. **No monolithic CameraManager** — Camera, Capture, and MultiCam are separate modules with clear boundaries.
2. **Protocol-first boundaries** — UI depends on protocols (`CameraControlling`, `NDISending`, etc.), never concrete types.
3. **Actor isolation for all mutable state** — Swift 6 strict concurrency from day one.
4. **NDI decoupled via protocol** — App compiles and runs fully without NDI SDK.
5. **Network.framework for HTTP server** — No third-party web server dependency. Uses `NWListener` and `NWConnection` directly.
6. **Capability-driven UI** — Every control checks hardware capability before rendering.

---

## Section 3 — Dependency Graph

> Full details in [DEPENDENCIES.md](file:///c:/Users/Tama/Desktop/NDI-camera/docs/DEPENDENCIES.md)

### 3.1 Build Order

```
1. Domain              → Foundation only
2. Diagnostics         → Domain
3. Capture             → Domain
4. MultiCam            → Domain, Capture
5. Camera              → Domain, Capture, MultiCam
6. Audio               → Domain
7. NDI                 → Domain, Diagnostics
8. WebController       → (static assets, copy phase)
9. Remote              → Domain, WebController
10. Persistence        → Domain
11. UI                 → Domain + all protocols
12. App                → Everything
```

### 3.2 External Dependencies

| Dependency | Status | Required For |
|---|---|---|
| NDI SDK (Vizrt) | ❌ NOT AVAILABLE | Real NDI output |
| Apple SDK (Xcode) | ✅ Required | Everything |

No third-party Swift packages.

---

## Section 4 — Module Boundaries (Detailed)

### 4.1 Domain Module

**Produces** (consumed by all other modules):

```swift
// Types
struct CameraDevice: Sendable, Identifiable, Hashable
struct CaptureFormat: Sendable, Identifiable
struct FPSRange: Sendable
enum CameraMode: String, Sendable, CaseIterable, Codable
enum StreamState: Sendable
struct AudioRoute: Sendable, Identifiable
enum Orientation: String, Sendable, Codable, CaseIterable
enum DisplayMode: Sendable
struct Preset: Sendable, Identifiable, Codable
struct NDIConfiguration: Sendable, Codable
struct NDIStatistics: Sendable
struct Capability: Sendable
struct DiagnosticsSnapshot: Sendable
struct PairingToken: Sendable
enum RemoteCommand: Sendable

// Protocols
protocol CameraControlling: Sendable
protocol CameraCapabilityProviding: Sendable
protocol AudioControlling: Sendable
protocol AudioCapabilityProviding: Sendable
protocol NDISending: Sendable
protocol NDIBackend: Sendable
protocol RemoteControlling: Sendable
protocol PairingManaging: Sendable
protocol MetricsProviding: Sendable
protocol FrameReceiving: Sendable
```

### 4.2 Camera Module

**Consumes**: Domain types, Capture pipeline, MultiCam coordinator
**Produces**: `CameraEngine` (conforms to `CameraControlling`, `CameraCapabilityProviding`)

```swift
actor CameraSessionActor {
    // All AVCaptureSession mutations serialized here
    func configureSession(mode: CameraMode, devices: [CameraDevice], format: CaptureFormat) async throws
    func setFocus(point: CGPoint, mode: AVCaptureDevice.FocusMode) async throws
    func setExposure(point: CGPoint, mode: AVCaptureDevice.ExposureMode) async throws
    func setZoom(factor: CGFloat, animated: Bool) async throws
    func setTorch(enabled: Bool, level: Float?) async throws
    func setStabilization(mode: AVCaptureVideoStabilizationMode) async throws
}
```

### 4.3 Capture Module

**Consumes**: Domain types
**Produces**: `CaptureCoordinator` (manages AVCaptureVideoDataOutput, delivers frames)

```swift
protocol FrameReceiving: Sendable {
    func didReceiveVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime, cameraID: String) async
    func didReceiveAudioFrame(_ sampleBuffer: CMSampleBuffer) async
}
```

### 4.4 MultiCam Module

**Consumes**: Domain, Capture
**Produces**: `MultiCamCoordinator` (validates combinations, manages multi-cam sessions)

```swift
struct MultiCamCapability: Sendable {
    let isSupported: Bool
    let viableDualCombinations: [(CameraDevice, CameraDevice)]
    let viableTripleCombinations: [(CameraDevice, CameraDevice, CameraDevice)]
}
```

### 4.5 Audio Module

**Consumes**: Domain
**Produces**: `AudioEngine` (conforms to `AudioControlling`, `AudioCapabilityProviding`)

```swift
actor AudioEngine: AudioControlling, AudioCapabilityProviding {
    func discoverRoutes() async -> [AudioRoute]
    func selectRoute(_ route: AudioRoute) async throws
    func setMuted(_ muted: Bool) async
    func setGain(_ gain: Float) async throws  // only when hardware permits
}
```

### 4.6 NDI Module

**Consumes**: Domain, Diagnostics
**Produces**: `NDIBackend` protocol + `MockNDIBackend` implementation

```swift
protocol NDIBackend: Sendable {
    func initialize() async throws
    func shutdown() async
    func createSender(name: String, group: String?) async throws -> any NDISending
    func capabilities() async -> NDICapabilities
}

protocol NDISending: Sendable {
    var sourceName: String { get }
    func sendVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) async
    func sendAudioFrame(_ sampleBuffer: CMSampleBuffer) async
    func sendMetadata(_ xml: String) async
    func statistics() async -> NDIStatistics
    func destroy() async
}
```

### 4.7 Remote Module

**Consumes**: Domain, WebController assets
**Produces**: `RemoteServer` (conforms to `RemoteControlling`, `PairingManaging`)

REST API endpoints as specified in `prompts/06_REMOTE.md`. WebSocket at `/ws` for real-time state broadcast.

### 4.8 Persistence Module

**Consumes**: Domain
**Produces**: `SettingsStore`, `PresetManager`

### 4.9 Diagnostics Module

**Consumes**: Domain
**Produces**: `DiagnosticsEngine` (conforms to `MetricsProviding`)

### 4.10 UI Module

**Consumes**: All protocols from Domain
**Produces**: SwiftUI views, view models

---

## Section 5 — Camera Pipeline Design

### 5.1 Single Camera Flow

```
AVCaptureDevice (discovered dynamically)
    │
    ▼
AVCaptureDeviceInput
    │
    ▼
AVCaptureSession (configured by CameraSessionActor)
    │
    ├── AVCaptureVideoPreviewLayer ──▶ SwiftUI preview (no copy)
    │
    ├── AVCaptureVideoDataOutput ──▶ captureOutputQueue (serial, non-main)
    │     │
    │     ▼
    │   CaptureCoordinator.captureOutput(_:didOutput:from:)
    │     │
    │     ▼
    │   FrameReceiving.didReceiveVideoFrame(CVPixelBuffer, CMTime, cameraID)
    │     │
    │     └──▶ NDISenderActor.sendVideoFrame(pixelBuffer, timestamp)
    │           │
    │           ├── Queue depth < max? ──▶ Enqueue for NDI send
    │           └── Queue depth ≥ max? ──▶ Drop frame, increment metric
    │
    └── AVCaptureAudioDataOutput ──▶ audioOutputQueue (serial, non-main)
          │
          ▼
        FrameReceiving.didReceiveAudioFrame(CMSampleBuffer)
          │
          └──▶ NDISenderActor.sendAudioFrame(sampleBuffer)
```

### 5.2 Format Selection Algorithm

```swift
func selectOptimalFormat(
    device: AVCaptureDevice,
    preferredResolution: CMVideoDimensions,
    preferredFPS: Float64,
    preferredPixelFormat: OSType
) -> AVCaptureDevice.Format? {
    // 1. Filter formats matching pixel format (prefer kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange for NDI)
    // 2. Filter formats supporting the preferred resolution
    // 3. Filter formats whose FPS ranges include the preferred FPS
    // 4. Sort by: exact resolution match > closest resolution > highest FPS support
    // 5. Return best match or nil
    // NEVER hard-code — always enumerate device.formats
}
```

### 5.3 Backpressure Policy

| Condition | Action |
|---|---|
| NDI queue depth < 3 frames | Enqueue frame normally |
| NDI queue depth ≥ 3 frames | Drop oldest frame, increment `droppedFrames` metric |
| Thermal pressure `.serious` | Reduce target FPS by 50% |
| Thermal pressure `.critical` | Drop to minimum resolution, warn user |
| Memory pressure > 80% | Reduce all queue depths to 1 |

---

## Section 6 — MultiCam Design

### 6.1 Capability Discovery

```swift
func discoverMultiCamCapabilities() -> MultiCamCapability {
    guard AVCaptureMultiCamSession.isMultiCamSupported else {
        return MultiCamCapability(isSupported: false, viableDualCombinations: [], viableTripleCombinations: [])
    }

    let allDevices = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
        mediaType: .video,
        position: .unspecified
    ).devices

    // Test each pair/triple for AVCaptureMultiCamSession compatibility
    // Use supportedMultiCamDeviceSets to determine valid combinations
    // Return only combinations that the hardware actually supports
}
```

### 6.2 Mode Architecture

| Mode | Sessions | NDI Sources | Composition |
|---|---|---|---|
| Single | `AVCaptureSession` | 1 | None |
| Dual Independent | `AVCaptureMultiCamSession` | 2 (separate names) | None |
| Dual Composite | `AVCaptureMultiCamSession` | 1 (composited) | Metal/CoreImage |
| Triple Independent | `AVCaptureMultiCamSession` | 3 (separate names) | None |
| Triple Composite | `AVCaptureMultiCamSession` | 1 (composited) | Metal/CoreImage |

### 6.3 Resource Budget Tracking

- Query `AVCaptureMultiCamSession` hardware cost for each connection
- Total hardware cost must stay under budget (query the session)
- If adding a camera would exceed budget, reject with clear error message
- System pressure from multi-cam is monitored and surfaced to diagnostics

---

## Section 7 — NDI Integration Strategy

### 7.1 Current Status: 🔴 BLOCKED

The `Vendor/NDI/` directory does not exist. No NDI SDK headers, frameworks, or module maps are present.

### 7.2 Strategy: Protocol Abstraction

```swift
// NDIBackend.swift
protocol NDIBackend: Sendable {
    func initialize() async throws
    func shutdown() async
    func createSender(name: String, group: String?) async throws -> any NDISending
    func capabilities() async -> NDICapabilities
}

// MockNDIBackend.swift — implements immediately
final actor MockNDIBackend: NDIBackend {
    // Simulates state transitions and metrics
    // Does NOT fake encoding or network I/O
    // Increments frame counters, simulates latency
    // Returns mock statistics for UI/diagnostics development
}

// RealNDIBackend.swift — BLOCKED, implement ONLY after SDK inspection
// #if canImport(NDILib)
// final actor RealNDIBackend: NDIBackend { ... }
// #endif
```

### 7.3 When SDK Becomes Available

1. Developer places NDI SDK in `Vendor/NDI/`
2. Engineer inspects **actual** headers: function names, struct layouts, constants
3. Creates C/Swift interop bridge targeting the **exact** API found in headers
4. Implements `RealNDIBackend` conforming to existing `NDIBackend` protocol
5. Conditional compilation: `#if canImport(NDILib)` selects real vs mock
6. Tests with NDI Studio Monitor on the same network
7. Capability flags gate UI features based on SDK tier (Standard vs Advanced)

### 7.4 NDI Frame Format Requirements

Based on the NDI SDK documentation (version 6.3.2):
- The standard SDK supports NDI High Bandwidth sending
- HX/HX3 receive/send may be available depending on SDK tier
- Frame format: The SDK typically expects UYVY or NV12 pixel data
- The exact format MUST be determined from the actual headers — **do not guess**

### 7.5 Backpressure and Flow Control

```
Camera Pipeline ──▶ NDISenderActor
                        │
                        ├── Bounded queue (max 3 video frames)
                        ├── Drop policy: oldest frame dropped
                        ├── Statistics tracked: sent, dropped, queue depth
                        └── NDI send call (async, non-blocking to pipeline)
```

---

## Section 8 — Audio Pipeline Design

### 8.1 Architecture

```
AVCaptureAudioDataOutput
    │
    ▼ (audioOutputQueue, serial, non-main)
AudioCaptureDelegate.captureOutput(_:didOutput:from:)
    │
    ├── Timestamp preserved from CMSampleBuffer
    ├── Channel count from format description
    └── Sample rate from format description
    │
    ▼
FrameReceiving.didReceiveAudioFrame(CMSampleBuffer)
    │
    └──▶ NDISenderActor.sendAudioFrame(sampleBuffer)
```

### 8.2 Route Discovery

```swift
// Discover available audio inputs
let availableInputs = AVAudioSession.sharedInstance().availableInputs ?? []
// Each AVAudioSessionPortDescription provides:
//   - portType: .builtInMic, .bluetoothHFP, .usbAudio, etc.
//   - portName: human-readable name
//   - dataSources: [AVAudioSessionDataSourceDescription]? (e.g., front/back mic)

// iOS does NOT allow arbitrary physical microphone capsule selection on all devices
// Only expose what the API actually provides
```

### 8.3 Features

| Feature | Implementation | Constraint |
|---|---|---|
| Route discovery | `AVAudioSession.availableInputs` | System-provided only |
| Mic selection | `AVAudioSession.setPreferredInput()` | Per-port, not per-capsule on all devices |
| Data source selection | `AVAudioSessionPortDescription.setPreferredDataSource()` | Only when `dataSources` is non-nil |
| Mute | Silence audio frames sent to NDI | Always available |
| Gain | `AVAudioSession.setInputGain()` | Only when `isInputGainSettable == true` |
| Route change notification | `AVAudioSession.routeChangeNotification` | Always |
| Interruption handling | `AVAudioSession.interruptionNotification` | Always |
| Sample rate | `AVAudioSession.setPreferredSampleRate()` | Preferred, not guaranteed |
| Channel count | From format description | Discovery only |

---

## Section 9 — Remote Control Architecture

### 9.1 Server Architecture

```
NWListener (TCP, port auto-assigned or user-configured)
    │
    ├── Bonjour advertisement: _tamandicam._tcp.
    │
    ├── HTTP Request Router
    │     │
    │     ├── GET /api/v1/status
    │     ├── GET /api/v1/capabilities
    │     ├── GET /api/v1/cameras
    │     ├── GET /api/v1/formats
    │     ├── GET /api/v1/settings
    │     ├── POST /api/v1/stream/start
    │     ├── POST /api/v1/stream/stop
    │     ├── POST /api/v1/camera/select
    │     ├── POST /api/v1/camera/zoom
    │     ├── POST /api/v1/camera/focus
    │     ├── POST /api/v1/exposure
    │     ├── POST /api/v1/torch
    │     ├── POST /api/v1/video
    │     ├── POST /api/v1/audio
    │     ├── POST /api/v1/orientation
    │     ├── POST /api/v1/display
    │     ├── POST /api/v1/preset/load
    │     └── POST /api/v1/pair (unauthenticated — pairing code exchange)
    │
    ├── WebSocket Upgrade Handler
    │     └── /ws — authenticated, broadcasts state changes
    │
    └── Static File Server
          └── Serves bundled web controller assets from app bundle
```

### 9.2 Security Model

```
Phase 1: Pairing
─────────────────
Phone displays: 6-digit pairing code (e.g., "482917")
    │
    ▼
Browser sends: POST /api/v1/pair { "code": "482917" }
    │
    ▼
Server validates code, returns: { "token": "<random-256-bit-hex>" }
    │
    ▼
Token stored in Keychain on phone
Browser stores token in localStorage

Phase 2: Authenticated Requests
────────────────────────────────
All subsequent requests include:
  Authorization: Bearer <token>

Phase 3: Revocation
───────────────────
Phone UI: "Revoke All Sessions" button
    │
    ▼
All stored tokens deleted from Keychain
All active WebSocket connections closed
```

### 9.3 Rate Limiting

| Endpoint Category | Limit |
|---|---|
| Pairing attempts | 5 per minute per IP |
| Control commands | 30 per second per token |
| Status queries | 60 per second per token |
| WebSocket connections | 3 per token |

---

## Section 10 — Web Dashboard Architecture

### 10.1 Pages/Panels

| Panel | Purpose | Data Source |
|---|---|---|
| Live Overview | Stream status, source name, FPS, bitrate, drops | WebSocket state events |
| Camera | Lens selection, zoom, focus, exposure | REST + WebSocket |
| Video | Resolution, FPS, stabilization, format | REST + WebSocket |
| Audio | Route, mute, gain | REST + WebSocket |
| NDI | Source name, group, stream control | REST + WebSocket |
| Orientation/Display | Orientation lock, dim/blackout | REST + WebSocket |
| Presets | Load/save presets | REST |
| Diagnostics | Metrics, thermal, memory, queue depths | WebSocket diagnostics events |

### 10.2 Communication Pattern

```
Browser                              iOS App
──────                              ───────
  │                                     │
  │──── WebSocket connect ──────────────▶│
  │◀─── state event ───────────────────│
  │                                     │
  │──── REST POST /api/v1/torch ────────▶│
  │◀─── { ok: true } ──────────────────│
  │◀─── state event (torch changed) ────│
  │                                     │
```

- **Optimistic UI**: Only for non-destructive controls (zoom, torch toggle). Reconciled against next WebSocket state event.
- **Authoritative state**: WebSocket state events are the source of truth. UI always reconciles against server state.

### 10.3 Tech Stack

- Vanilla JavaScript (modern browser APIs, no framework)
- CSS Grid/Flexbox, dark theme, responsive
- WebSocket with auto-reconnect (1.5s delay)
- Existing `web/` prototype enhanced and expanded

---

## Section 11 — Testing Strategy

### 11.1 Test Matrix

| Layer | Test Type | Mock Dependencies | Hardware Required |
|---|---|---|---|
| Domain | Unit | None | No |
| Camera (format filtering) | Unit | None (pure functions) | No |
| Camera (session config) | Unit | Mock AVCaptureSession | No |
| MultiCam (combination validation) | Unit | Mock device list | No |
| Audio (route discovery) | Unit | Mock AVAudioSession | No |
| NDI (MockBackend behavior) | Unit | MockNDIBackend | No |
| NDI (RealBackend) | Integration | Real SDK | Yes (+ NDI receiver) |
| Remote (REST commands) | Unit | Mock domain layer | No |
| Remote (pairing/tokens) | Unit | None | No |
| Persistence (presets) | Unit | None | No |
| Persistence (downgrade logic) | Unit | Mock capabilities | No |
| Web Controller | Manual | Browser + LAN | Yes |
| UI (critical flows) | UI Test | Mock all backends | Simulator |
| Full integration | Manual | Real SDK + hardware | Yes |

### 11.2 Mock Hierarchy

```swift
// All tests run without physical hardware
MockCameraEngine: CameraControlling, CameraCapabilityProviding
MockAudioEngine: AudioControlling, AudioCapabilityProviding
MockNDIBackend: NDIBackend
MockNDISender: NDISending
MockRemoteServer: RemoteControlling
MockPairingManager: PairingManaging
MockDiagnosticsEngine: MetricsProviding
```

### 11.3 Hardware Test Checklist

Tests that CANNOT run in Simulator — must be verified on real devices:

- [ ] Single lens capture (all available lenses)
- [ ] Dual camera capture (all viable pairs)
- [ ] Triple camera capture (where supported)
- [ ] 4K30, 4K60, 1080p60, 1080p120, 1080p240 (where supported)
- [ ] Torch on/off with intensity
- [ ] All stabilization modes
- [ ] Audio route changes (Bluetooth, USB, built-in)
- [ ] Thermal throttling behavior
- [ ] Wi-Fi congestion impact on NDI
- [ ] App interruption (phone call, notification)
- [ ] Background/foreground transitions
- [ ] Memory pressure response
- [ ] NDI output verified with NDI Studio Monitor
- [ ] Bonjour discovery from another device
- [ ] Web controller from desktop browser
- [ ] Web controller from tablet browser

---

## Section 12 — Performance Strategy

### 12.1 Pipeline Performance Budget

| Stage | Target Latency | Measurement |
|---|---|---|
| Frame capture → delegate callback | < 1ms | os_signpost |
| Delegate → NDI enqueue | < 0.5ms | os_signpost |
| NDI send (mock) | < 0.1ms | os_signpost |
| NDI send (real, estimated) | < 5ms | os_signpost + SDK metrics |
| End-to-end (capture → NDI wire) | < 10ms | os_signpost interval |
| WebSocket state broadcast | < 2ms | os_signpost |

### 12.2 Memory Budget

| Resource | Budget | Monitoring |
|---|---|---|
| Single camera pixel buffers | ~50 MB (4K) | Pool allocation tracking |
| Dual camera pixel buffers | ~100 MB | Pool allocation tracking |
| Triple camera pixel buffers | ~150 MB | Pool allocation tracking |
| NDI send queue | 3 frames max | Queue depth metric |
| Audio buffer pool | ~5 MB | Allocation tracking |
| Total app footprint target | < 300 MB | `os_proc_available_memory()` |

### 12.3 Instrumentation Points

```swift
// os_signpost intervals for Instruments
let signposter = OSSignposter(subsystem: "com.tamandicam", category: "Pipeline")

// Key intervals:
"frame-capture"     // AVCaptureOutput callback duration
"frame-to-ndi"      // From callback to NDI enqueue
"ndi-send"          // NDI send call duration
"audio-capture"     // Audio callback duration
"remote-command"    // REST command processing
"ws-broadcast"      // WebSocket state broadcast
"session-configure" // AVCaptureSession configuration
```

### 12.4 Frame Drop Policy

1. AVFoundation drops late frames automatically (`alwaysDiscardsLateVideoFrames`)
2. NDI sender drops frames when queue is full (bounded at 3)
3. Under thermal pressure: target FPS reduced
4. Under memory pressure: queue depths reduced to 1
5. All drops counted and surfaced in diagnostics

---

## Section 13 — Security Model

### 13.1 Threat Model

| Threat | Mitigation |
|---|---|
| Unauthorized camera control | Pairing code + bearer token |
| Token theft via network sniffing | LAN-only binding, recommend HTTPS in docs |
| Token persistence on compromised browser | Tokens revocable from phone |
| Brute-force pairing code | Rate limiting (5 attempts/min/IP) |
| Malformed API input | Strict Codable decoding, input validation |
| Token in logs | Tokens never logged |
| Token in settings export | Export sanitizes all secrets |
| Open WebSocket flooding | 3 connections per token, message rate limiting |

### 13.2 Token Lifecycle

```
Generate pairing code (6 digits, 5-minute expiry)
    │
    ▼
Browser submits code → Server validates → Issue 256-bit random token
    │
    ▼
Token stored in iOS Keychain (not UserDefaults)
    │
    ▼
Token used in Authorization header for all requests
    │
    ▼
Token revoked: explicitly via UI, or on pairing code regeneration
```

### 13.3 Privacy Manifest

Required entries for App Store:
- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSLocalNetworkUsageDescription`
- `NSBonjourServices`: `["_tamandicam._tcp."]`
- Privacy manifest (PrivacyInfo.xcprivacy) if required by NDI SDK

---

## Section 14 — Build and Deployment Strategy

### 14.1 Xcode Project Structure

```
TamaNDI/
├── TamaNDI.xcodeproj
├── TamaNDI/
│   ├── App/
│   │   ├── TamaNDIApp.swift
│   │   ├── DependencyContainer.swift
│   │   └── Info.plist
│   ├── Domain/
│   │   ├── Models/
│   │   └── Protocols/
│   ├── Camera/
│   │   ├── CameraEngine.swift
│   │   ├── CameraSessionActor.swift
│   │   └── FormatHelpers.swift
│   ├── Capture/
│   │   ├── CaptureCoordinator.swift
│   │   └── FrameReceiving.swift
│   ├── MultiCam/
│   │   ├── MultiCamCoordinator.swift
│   │   └── CombinationValidator.swift
│   ├── Audio/
│   │   ├── AudioEngine.swift
│   │   └── AudioRouteMonitor.swift
│   ├── NDI/
│   │   ├── NDIBackend.swift
│   │   ├── MockNDIBackend.swift
│   │   ├── NDISenderActor.swift
│   │   ├── NDIVideoPipeline.swift
│   │   ├── NDIAudioPipeline.swift
│   │   ├── NDIConfiguration.swift
│   │   └── NDIStatistics.swift
│   ├── Remote/
│   │   ├── RemoteServer.swift
│   │   ├── HTTPRouter.swift
│   │   ├── WebSocketHandler.swift
│   │   ├── PairingManager.swift
│   │   └── BonjourAdvertiser.swift
│   ├── WebController/
│   │   ├── index.html
│   │   ├── app.js
│   │   └── style.css
│   ├── Persistence/
│   │   ├── SettingsStore.swift
│   │   └── PresetManager.swift
│   ├── Diagnostics/
│   │   ├── DiagnosticsEngine.swift
│   │   ├── MetricsCollector.swift
│   │   └── LoggingSubsystem.swift
│   ├── UI/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Components/
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── PrivacyInfo.xcprivacy
│   └── Vendor/
│       └── NDI/
│           └── (developer places SDK here)
├── TamaNDITests/
│   ├── DomainTests/
│   ├── CameraTests/
│   ├── MultiCamTests/
│   ├── AudioTests/
│   ├── NDITests/
│   ├── RemoteTests/
│   ├── PersistenceTests/
│   ├── DiagnosticsTests/
│   └── Mocks/
├── TamaNDIUITests/
│   └── CriticalFlowTests.swift
└── docs/
    ├── ARCHITECTURE.md
    ├── DEPENDENCIES.md
    ├── RISKS.md
    ├── MASTER_PLAN.md
    ├── SETUP.md
    ├── NDI_SDK_SETUP.md
    └── TROUBLESHOOTING.md
```

### 14.2 Build Configurations

| Configuration | NDI | Use Case |
|---|---|---|
| Debug (Mock NDI) | MockNDIBackend | Daily development |
| Debug (Real NDI) | RealNDIBackend | SDK integration testing |
| Release | RealNDIBackend (if available) | Distribution |

### 14.3 Commit Sequence

Following `prompts/14_AGENT_WORKFLOW.md`:

```
01  Foundation — project skeleton, domain types, protocols, DI container
02  Camera — device discovery, format enumeration, session management
03  Multi-camera — MultiCam coordinator, combination validation
04  Audio — route discovery, audio capture, gain/mute
05  NDI adapter — MockNDIBackend, NDISenderActor, pipelines
06  Remote API — HTTP server, REST endpoints, pairing
07  Web controller — enhanced dashboard
08  Presets — persistence, import/export, downgrade logic
09  Diagnostics — metrics, logging, signposts
10  Tests — unit tests, UI tests, mock infrastructure
11  Production hardening — permissions, privacy manifest, error handling
12  Final QA — integration, documentation, build verification
```

Each commit must:
- Build successfully (simulator target when no hardware)
- Pass all existing tests
- Include documentation for new APIs
- Fix all compiler warnings

---

## Section 15 — Risk Register Summary

> Full details in [RISKS.md](file:///c:/Users/Tama/Desktop/NDI-camera/docs/RISKS.md)

| ID | Risk | Severity | Status |
|---|---|---|---|
| R-001 | NDI SDK unavailable | 🔴 Critical | **ACTIVE** |
| R-002 | NDI API invention | 🔴 Critical | Mitigated by policy |
| R-003 | MultiCam hardware assumptions | 🟠 High | Mitigated by design |
| R-004 | Camera pipeline performance | 🟠 High | Mitigated by design |
| R-005 | AV sync | 🟠 High | Open |
| R-006 | Thermal throttling | 🟠 High | Open |
| R-007 | Remote control security | 🟠 High | Mitigated by design |
| R-008 | iOS background limitations | 🟡 Medium | Accepted |
| R-009 | App Store NDI rejection | 🟡 Medium | Open |
| R-010 | Local network permission | 🟡 Medium | Open |
| R-011 | Swift 6 strict concurrency | 🟡 Medium | Open |
| R-012 | Memory pressure (multi-cam) | 🟡 Medium | Open |
| R-013 | NDI SDK licensing tiers | 🟡 Medium | Open |
| R-014 | Web cross-browser compat | 🟢 Low | Open |
| R-015 | Settings schema evolution | 🟢 Low | Open |

---

## Section 16 — Implementation Task Overview

### Phase 1: Foundation (Commit 01)
- [ ] Create Xcode project with deployment target iOS 18.0
- [ ] Configure Swift 6 strict concurrency
- [ ] Create .gitignore
- [ ] Create Domain module with all model types
- [ ] Create all protocol definitions
- [ ] Create DependencyContainer
- [ ] Create app entry point with permission flow
- [ ] Create logging subsystem with os.Logger
- [ ] Create NDIBackend protocol and MockNDIBackend
- [ ] Create test target with first test (model encoding/decoding)
- [ ] Commit and verify build

### Phase 2: Camera Engine (Commit 02)
- [ ] Implement CameraSessionActor
- [ ] Implement device discovery via AVCaptureDevice.DiscoverySession
- [ ] Implement format enumeration and filtering (pure functions)
- [ ] Implement CaptureCoordinator with AVCaptureVideoDataOutput
- [ ] Implement focus, exposure, zoom, torch controls
- [ ] Implement stabilization (dynamic mode discovery)
- [ ] Implement interruption handling
- [ ] Write unit tests for format filtering helpers
- [ ] Commit and verify build + tests

### Phase 3: Multi-Camera (Commit 03)
- [ ] Implement MultiCamCoordinator
- [ ] Implement combination validation using AVCaptureMultiCamSession API
- [ ] Implement resource budget tracking
- [ ] Implement independent mode (separate frame sinks)
- [ ] Implement composite mode (Metal/CoreImage composition)
- [ ] Write unit tests for combination validation
- [ ] Commit and verify build + tests

### Phase 4: Audio Engine (Commit 04)
- [ ] Implement AudioEngine actor
- [ ] Implement route discovery
- [ ] Implement mic/data source selection
- [ ] Implement mute and gain (capability-gated)
- [ ] Implement route change notification handling
- [ ] Implement interruption handling
- [ ] Write unit tests for route handling logic
- [ ] Commit and verify build + tests

### Phase 5: NDI Adapter (Commit 05)
- [ ] Finalize NDIBackend protocol
- [ ] Implement MockNDIBackend with simulated metrics
- [ ] Implement NDISenderActor with bounded queue
- [ ] Implement NDIVideoPipeline (frame format preparation)
- [ ] Implement NDIAudioPipeline (sample buffer routing)
- [ ] Implement NDIStatistics collection
- [ ] Implement backpressure/frame drop policy
- [ ] Write unit tests for MockNDIBackend behavior
- [ ] Write unit tests for queue/drop policy
- [ ] Commit and verify build + tests

### Phase 6: Remote API (Commit 06)
- [ ] Implement RemoteServer with NWListener
- [ ] Implement HTTP request router with all endpoints
- [ ] Implement WebSocket handler with state broadcast
- [ ] Implement PairingManager with code generation and token exchange
- [ ] Implement BonjourAdvertiser
- [ ] Implement rate limiting
- [ ] Implement token authentication middleware
- [ ] Write unit tests for command decoding
- [ ] Write unit tests for pairing/token logic
- [ ] Commit and verify build + tests

### Phase 7: Web Controller (Commit 07)
- [ ] Enhance existing web prototype with all panels
- [ ] Add diagnostics panel
- [ ] Add preset management panel
- [ ] Add orientation/display panel
- [ ] Implement WebSocket auto-reconnect
- [ ] Implement optimistic UI with reconciliation
- [ ] Test on Safari, Chrome, Firefox
- [ ] Commit and verify build

### Phase 8: Presets (Commit 08)
- [ ] Implement SettingsStore
- [ ] Implement PresetManager with built-in presets
- [ ] Implement capability-aware preset loading with downgrade
- [ ] Implement JSON import/export (sanitized — no tokens)
- [ ] Implement schema versioning
- [ ] Write unit tests for preset downgrade logic
- [ ] Write unit tests for import/export validation
- [ ] Commit and verify build + tests

### Phase 9: Diagnostics (Commit 09)
- [ ] Implement DiagnosticsEngine
- [ ] Implement MetricsCollector (FPS, drops, queue depth, thermal, memory)
- [ ] Add os_signpost instrumentation to pipeline
- [ ] Implement in-app diagnostics screen
- [ ] Implement JSON diagnostics export (no secrets)
- [ ] Write unit tests for metric collection
- [ ] Commit and verify build + tests

### Phase 10: Test Suite (Commit 10)
- [ ] Complete unit test coverage for all modules
- [ ] Create UI tests for critical flows (stream start/stop, camera selection, settings)
- [ ] Create mock infrastructure for UI tests
- [ ] Create hardware test checklist document
- [ ] Verify all tests pass in simulator
- [ ] Commit and verify build + tests

### Phase 11: Production Hardening (Commit 11)
- [ ] Add all NSUsageDescription keys
- [ ] Add Bonjour service declarations
- [ ] Add PrivacyInfo.xcprivacy
- [ ] Configure release build settings
- [ ] Implement first-run permission flow
- [ ] Implement crash-safe error handling
- [ ] Add terms/license screen placeholder
- [ ] Create SETUP.md
- [ ] Create NDI_SDK_SETUP.md
- [ ] Create TROUBLESHOOTING.md
- [ ] Commit and verify build + tests

### Phase 12: Final QA (Commit 12)
- [ ] Full integration pass
- [ ] Verify all 20 acceptance criteria from prompts/13
- [ ] Verify all compiler warnings resolved
- [ ] Final documentation review
- [ ] Tag release candidate
- [ ] Commit and verify build + tests

---

## Appendix A — File Inventory (Estimated)

| Category | Estimated Files | Estimated LoC |
|---|---|---|
| Domain models & protocols | 15–20 | 800–1200 |
| Camera engine | 5–8 | 600–900 |
| Multi-cam coordinator | 3–5 | 400–600 |
| Audio engine | 3–4 | 300–400 |
| NDI adapter (mock) | 7–8 | 500–700 |
| Remote server | 5–7 | 700–1000 |
| Web controller | 3–5 | 400–600 |
| Persistence | 2–3 | 200–300 |
| Diagnostics | 3–4 | 300–400 |
| UI (views + view models) | 15–20 | 1500–2000 |
| App layer | 2–3 | 150–200 |
| Tests | 15–20 | 1500–2000 |
| Documentation | 5–7 | — |
| **Total** | **~80–110** | **~7,000–10,000** |

---

## Appendix B — Decision Log

| # | Decision | Rationale |
|---|---|---|
| D-001 | Use Network.framework for HTTP server | No third-party dependency. Native performance. Bonjour integration. |
| D-002 | Actor-based camera session | Swift 6 strict concurrency. AVCaptureSession is not thread-safe. |
| D-003 | Protocol-first NDI abstraction | SDK not available. App must compile without it. |
| D-004 | No UIImage in pipeline | Performance requirement. CVPixelBuffer avoids copies. |
| D-005 | Vanilla JS for web dashboard | No build tools needed. Served from app bundle. Small footprint. |
| D-006 | os.Logger + os_signpost | Apple-native diagnostics. Instruments integration. No third-party logging. |
| D-007 | Keychain for token storage | UserDefaults is not secure for bearer tokens. |
| D-008 | Dynamic capability discovery | Never assume device features. Required by AGENTS.md. |
| D-009 | Bounded NDI send queue (3 frames) | Prevents memory growth and pipeline stalls. |
| D-010 | iOS 18.0 minimum target | Swift 6, latest AVFoundation APIs, @Observable macro. |
