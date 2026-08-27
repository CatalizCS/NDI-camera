# TamaNDI — Risk Register

> **Status**: Design Phase
> **Date**: 2026-08-28
> **Review cadence**: Re-assess after each implementation milestone

---

## Risk Severity Scale

| Level | Impact | Likelihood |
|---|---|---|
| 🔴 Critical | Blocks release or causes data loss / security breach | > 70% |
| 🟠 High | Degrades core functionality significantly | 40–70% |
| 🟡 Medium | Causes inconvenience or limits features | 20–40% |
| 🟢 Low | Minor cosmetic or edge-case issue | < 20% |

---

## Risk Register

### R-001: NDI SDK Unavailable
| Attribute | Value |
|---|---|
| **Severity** | 🔴 Critical |
| **Category** | Dependency |
| **Status** | **ACTIVE — CONFIRMED** |
| **Description** | The `Vendor/NDI/` directory does not exist. No NDI SDK headers, frameworks, or module maps are present. The app cannot perform real NDI sending without the official SDK from Vizrt. |
| **Impact** | All NDI output functionality is blocked. The app can only operate in mock mode. |
| **Mitigation** | 1. Design `NDIBackend` protocol abstraction immediately. 2. Implement `MockNDIBackend` for development. 3. Document exact SDK placement instructions in `NDI_SDK_SETUP.md`. 4. Use `#if canImport(NDILib)` conditional compilation. 5. The app remains fully functional for camera preview, audio, remote control — only NDI output is stubbed. |
| **Owner** | Developer (must obtain SDK from Vizrt) |
| **Resolution** | Developer obtains NDI SDK (standard or Advanced), places XCFramework and headers in `Vendor/NDI/`, and implements `RealNDIBackend` against actual headers. |

---

### R-002: NDI API Invention
| Attribute | Value |
|---|---|
| **Severity** | 🔴 Critical |
| **Category** | Implementation |
| **Status** | Mitigated by policy |
| **Description** | Risk of implementing NDI integration using invented/guessed C function signatures that don't match the real SDK. |
| **Impact** | Code won't compile with real SDK. Wasted implementation effort. Potential runtime crashes. |
| **Mitigation** | 1. AGENTS.md explicitly prohibits inventing NDI APIs. 2. `NDIBackend` protocol decouples the app from SDK specifics. 3. Real implementation MUST be written by inspecting actual headers in `Vendor/NDI/`. 4. Code review gate: any PR touching NDI must reference specific header file and line. |
| **Owner** | Engineering team |

---

### R-003: Multi-Camera Hardware Assumptions
| Attribute | Value |
|---|---|
| **Severity** | 🟠 High |
| **Category** | Implementation |
| **Status** | Mitigated by design |
| **Description** | Risk of hard-coding camera combinations (e.g., assuming all devices support wide+telephoto dual capture). |
| **Impact** | Crashes or broken UI on devices that don't support assumed configurations. |
| **Mitigation** | 1. All camera capabilities discovered dynamically via `AVCaptureDevice.DiscoverySession`. 2. Multi-cam validated via `AVCaptureMultiCamSession.isMultiCamSupported` and hardware cost queries. 3. UI only shows supported modes. 4. Unit tests with mock capability sets. |
| **Owner** | Camera Engine module |

---

### R-004: Camera Pipeline Performance
| Attribute | Value |
|---|---|
| **Severity** | 🟠 High |
| **Category** | Performance |
| **Status** | Mitigated by design |
| **Description** | Risk of frame drops, stuttering, or main-thread blocking in the camera-to-NDI pipeline. |
| **Impact** | Poor user experience. Unreliable broadcast output. |
| **Mitigation** | 1. Zero `UIImage` conversions. 2. `CVPixelBuffer` passed by reference. 3. Dedicated serial queues for capture callbacks. 4. NDI sender has bounded queue with frame dropping. 5. `os_signpost` instrumentation for pipeline profiling. 6. `alwaysDiscardsLateVideoFrames = true`. |
| **Owner** | Capture Pipeline, NDI Adapter |

---

### R-005: Audio-Video Timestamp Synchronization
| Attribute | Value |
|---|---|
| **Severity** | 🟠 High |
| **Category** | Implementation |
| **Status** | Open |
| **Description** | Audio and video frames must maintain synchronized timestamps for NDI output. |
| **Impact** | Lip-sync drift in NDI output. |
| **Mitigation** | 1. Use `CMSampleBuffer` timestamps from AVFoundation (both audio and video use the same clock). 2. Preserve original `CMTime` values through the pipeline. 3. Do not re-stamp frames. 4. Test with Instruments and NDI Studio Monitor. |
| **Owner** | Capture Pipeline, Audio Engine, NDI Adapter |

---

### R-006: Thermal Throttling
| Attribute | Value |
|---|---|
| **Severity** | 🟠 High |
| **Category** | Platform |
| **Status** | Open |
| **Description** | Sustained 4K60 capture + NDI encoding + network I/O will cause thermal pressure on iOS devices. |
| **Impact** | iOS may throttle CPU/GPU, reduce camera FPS, or terminate the app. |
| **Mitigation** | 1. Monitor `ProcessInfo.thermalState` and `AVCaptureDevice.SystemPressureState`. 2. Automatically reduce resolution/FPS when pressure is elevated. 3. Surface thermal warnings in UI and remote dashboard. 4. Document thermal behavior per device class. |
| **Owner** | Diagnostics, Camera Engine |

---

### R-007: Network Security — Remote Control
| Attribute | Value |
|---|---|
| **Severity** | 🟠 High |
| **Category** | Security |
| **Status** | Mitigated by design |
| **Description** | LAN-exposed HTTP/WebSocket server could be accessed by unauthorized users. |
| **Impact** | Unauthorized camera control. |
| **Mitigation** | 1. Pairing code required for initial authentication. 2. Bearer token for subsequent requests. 3. Tokens stored in Keychain (not UserDefaults). 4. "Revoke All" capability. 5. Bind to LAN interfaces only. 6. Rate limiting on all endpoints. 7. Tokens never logged or exported. |
| **Owner** | Remote Server module |

---

### R-008: iOS Background Limitations
| Attribute | Value |
|---|---|
| **Severity** | 🟡 Medium |
| **Category** | Platform |
| **Status** | Accepted limitation |
| **Description** | iOS does not allow camera capture to continue when the app is fully backgrounded. The display cannot be turned off while maintaining foreground capture. |
| **Impact** | Users cannot lock the screen while streaming. Battery drain from screen-on requirement. |
| **Mitigation** | 1. Implement screen dimming and black preview while keeping the app in foreground. 2. Use `UIApplication.shared.isIdleTimerDisabled = true` during streaming. 3. Document the limitation clearly. 4. Do NOT claim the app can capture in background. |
| **Owner** | UI Layer, Orientation/Display module |

---

### R-009: App Store Rejection — NDI SDK
| Attribute | Value |
|---|---|
| **Severity** | 🟡 Medium |
| **Category** | Distribution |
| **Status** | Open |
| **Description** | The NDI SDK may contain private API usage or require specific entitlements that could trigger App Store review issues. |
| **Impact** | App Store rejection or delayed review. |
| **Mitigation** | 1. Review NDI SDK's privacy manifest. 2. Include all required `NSUsageDescription` keys. 3. Declare Bonjour service types in Info.plist. 4. Test with `altool` validation before submission. 5. Prepare justification for local network usage. |
| **Owner** | Build & Distribution |

---

### R-010: Bonjour / Local Network Permission
| Attribute | Value |
|---|---|
| **Severity** | 🟡 Medium |
| **Category** | Platform |
| **Status** | Open |
| **Description** | iOS requires explicit user permission for local network access. Users may deny the permission. |
| **Impact** | Remote control feature becomes non-functional. NDI discovery may be affected. |
| **Mitigation** | 1. Clear `NSLocalNetworkUsageDescription` explaining why. 2. Graceful degradation — app works fully without remote control. 3. UI prompt guiding users to re-enable if denied. |
| **Owner** | Remote Server, App Layer |

---

### R-011: Swift 6 Strict Concurrency
| Attribute | Value |
|---|---|
| **Severity** | 🟡 Medium |
| **Category** | Implementation |
| **Status** | Open |
| **Description** | Swift 6's strict concurrency checking will flag many patterns common in AVFoundation callback-based code. |
| **Impact** | Significant refactoring if not designed for from the start. Compiler errors with `Sendable` requirements. |
| **Mitigation** | 1. Design all actors and isolation boundaries from day one. 2. Use `@Sendable` closures. 3. Mark all model types as `Sendable`. 4. Use `nonisolated` sparingly and with justification. 5. Enable strict concurrency warnings from first commit. |
| **Owner** | All modules |

---

### R-012: Memory Pressure from Multi-Camera
| Attribute | Value |
|---|---|
| **Severity** | 🟡 Medium |
| **Category** | Performance |
| **Status** | Open |
| **Description** | Running 2–3 camera streams simultaneously with NDI output will consume significant memory. |
| **Impact** | iOS may terminate the app under memory pressure. |
| **Mitigation** | 1. Monitor `os_proc_available_memory()`. 2. Use shared pixel buffer pools. 3. Reduce queue depths under pressure. 4. Consider dropping to single-camera mode under severe pressure. 5. Profile with Instruments on target devices. |
| **Owner** | MultiCam Coordinator, Diagnostics |

---

### R-013: NDI SDK Licensing — Standard vs Advanced
| Attribute | Value |
|---|---|
| **Severity** | 🟡 Medium |
| **Category** | Business |
| **Status** | Open |
| **Description** | The standard NDI SDK may not support all desired encoding modes (e.g., native HX3 encoding). NDI Advanced requires a commercial license. |
| **Impact** | Some features may be unavailable without NDI Advanced. |
| **Mitigation** | 1. Capability-driven design — query SDK for supported features at runtime. 2. Disable UI for unsupported features. 3. Document which features require which SDK tier. 4. Never fake a capability the SDK doesn't expose. |
| **Owner** | NDI Adapter, Business team |

---

### R-014: Web Controller Cross-Browser Compatibility
| Attribute | Value |
|---|---|
| **Severity** | 🟢 Low |
| **Category** | Implementation |
| **Status** | Open |
| **Description** | The web dashboard must work on desktop browsers and tablets over LAN. |
| **Impact** | Broken controls on some browsers. |
| **Mitigation** | 1. Use vanilla JS with no framework. 2. Test on Safari, Chrome, Firefox. 3. Use standard CSS Grid/Flexbox. 4. No bleeding-edge browser APIs. |
| **Owner** | Web Controller |

---

### R-015: Settings Schema Evolution
| Attribute | Value |
|---|---|
| **Severity** | 🟢 Low |
| **Category** | Maintenance |
| **Status** | Open |
| **Description** | The settings JSON schema will evolve. Existing presets/exports may become incompatible. |
| **Impact** | User presets from older versions may fail to load. |
| **Mitigation** | 1. Version the schema. 2. Implement migration logic. 3. Validate on import with clear error messages. 4. Never crash on malformed input. |
| **Owner** | Persistence module |

---

## Summary

| Severity | Count | Active/Confirmed |
|---|---|---|
| 🔴 Critical | 2 | 1 (R-001 NDI SDK) |
| 🟠 High | 5 | 2 (R-005, R-006) |
| 🟡 Medium | 5 | 4 |
| 🟢 Low | 2 | 2 |

> **Blocking risk**: R-001 (NDI SDK unavailable) blocks all real NDI output. The entire app architecture, camera pipeline, audio pipeline, remote control, and UI can be built and tested with `MockNDIBackend`. Real NDI integration requires the developer to obtain and install the SDK.
