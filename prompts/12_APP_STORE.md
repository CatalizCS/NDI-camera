# Prompt 12 — Production hardening and App Store

Prepare the project for TestFlight/App Store distribution.

Include:
- camera usage description
- microphone usage description
- local network usage description
- Bonjour service declarations if needed
- supported interface orientations
- privacy manifest if required by the selected SDK/dependencies
- release build settings
- symbol stripping without breaking diagnostics
- crash-safe error handling
- clear first-run permission flow
- terms/license screen for NDI SDK integration
- README explaining how the developer supplies the official NDI SDK

Never bundle an NDI SDK binary from an unknown source.
