# Prompt 14 — Coding-agent workflow

Work in small, verifiable commits.

Commit sequence:
01 foundation
02 camera
03 multi-camera
04 audio
05 NDI adapter
06 remote API
07 web controller
08 presets
09 diagnostics
10 tests
11 production hardening
12 final QA

After each stage:
- run `xcodebuild` for the available simulator target where possible
- run unit tests
- run SwiftFormat/SwiftLint only if configured
- inspect compiler warnings
- fix errors before moving on
- update docs
- commit with a descriptive message

If a real-device-only feature cannot run in Simulator, keep a mock path and document the hardware test.
