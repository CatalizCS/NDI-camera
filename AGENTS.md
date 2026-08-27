# TamaNDI Engineering Rules

## Product

TamaNDI is a professional iOS NDI camera application.

## Platform

- iOS 18+
- Swift 6
- SwiftUI
- AVFoundation
- Network.framework
- Bonjour
- Swift Concurrency

## Architecture

Use modular architecture.

Never create a monolithic CameraManager.

Separate:

- Capture
- Camera devices
- MultiCam
- Audio
- NDI
- Remote server
- UI
- Persistence
- Diagnostics

## NDI

NEVER invent NDI APIs.

The agent MUST inspect the actual NDI SDK headers/module
available in Vendor/NDI before implementing integration.

If the SDK is unavailable:

implement an NDIBackend protocol and MockNDIBackend.

Do NOT fake an NDI implementation.

## Camera

All camera capabilities must be discovered dynamically.

Never assume:

- available lenses
- supported resolutions
- supported FPS
- supported stabilization modes
- MultiCam combinations

## MultiCam

Always check:

AVCaptureMultiCamSession.isMultiCamSupported

and validate device/format combinations.

## Performance

Avoid:

- unnecessary frame copies
- UIImage conversion in capture pipeline
- main-thread image processing
- blocking camera queues

Prefer:

CVPixelBuffer
Metal
CoreVideo
IOSurface where appropriate

## Concurrency

Use Swift Concurrency.

Actors should protect mutable shared state.

Camera callbacks must not mutate SwiftUI state directly.

## Testing

Every subsystem requires tests.

Every feature must provide:

1. implementation
2. unit tests
3. diagnostics
4. failure handling
5. documentation

## Verification

Never claim completion without:

- building
- running tests
- inspecting compiler errors
- checking runtime logs
- verifying behavior

## Git

Make small atomic commits.

Never rewrite unrelated files.

Never remove working functionality without explicit instruction.