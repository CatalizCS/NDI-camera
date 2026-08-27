# Prompt 02 — Camera engine

Implement a production-grade AVFoundation camera engine.

Requirements:
- discover all compatible front/rear camera devices
- expose human-friendly lens labels
- enumerate supported formats and FPS ranges
- select an exact format/fps combination
- configure pixel format suitable for the downstream NDI pipeline
- support preview and video-data output
- configure focus, exposure, zoom and torch
- configure stabilization only when supported
- recover from runtime errors and interruptions
- publish capability/state changes safely to SwiftUI

Use a dedicated actor or serialized session queue for AVCaptureSession mutations. Never mutate the session concurrently from multiple threads.

Create unit-testable pure helpers for filtering/sorting capture formats.
