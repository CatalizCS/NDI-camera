# TamaNDI iOS Build Kit

A complete prompt package for generating a Swift/SwiftUI iOS NDI camera application.

## Target
- Native Swift + SwiftUI
- AVFoundation / AVCaptureMultiCamSession
- NDI SDK integration behind an abstraction layer
- Single, dual and triple camera modes where supported by the device
- Resolution/FPS capability discovery
- NDI output configuration
- Audio input selection
- Torch, zoom, focus, exposure, stabilization
- Orientation and lock
- Preview blackout/dimming without stopping capture
- Local browser remote control over LAN
- Bonjour discovery + pairing token
- REST + WebSocket API
- Tally/metadata hooks
- Diagnostics and performance telemetry

## Important NDI licensing note
The repository intentionally does NOT contain NDI SDK binaries or proprietary headers. Obtain the appropriate NDI SDK/NDI Advanced SDK from Vizrt/NDI and place the supplied XCFramework/headers in the project according to the integration prompt. Current official NDI materials list SDK version 6.3.2 and distinguish the standard Software SDK from NDI Advanced. The standard SDK page currently documents NDI High Bandwidth sending and HX/HX3 receive/send capabilities; NDI Advanced is the commercial option for full native format encoding and deeper connectivity controls.

## Build order
1. Read `prompts/00_SYSTEM_PROMPT.md`.
2. Give the agent `prompts/01_ARCHITECTURE.md`.
3. Run prompts 02–12 sequentially, committing after each stage.
4. Run `prompts/13_INTEGRATION_AND_QA.md` last.
5. Add the real NDI SDK locally; never fake NDI APIs.

## Asset policy
The included assets are intentionally original/simple SVG assets for the app UI. They are not NDI trademarks and do not include proprietary logos.
