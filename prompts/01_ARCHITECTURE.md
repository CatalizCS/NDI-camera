# Prompt 01 — Architecture and Xcode foundation

Create the complete Xcode project skeleton for TamaNDI.

Use SwiftUI and Swift Package Manager only for non-proprietary dependencies. Prefer Apple frameworks. Minimum deployment target should be chosen from the installed SDK and current iOS camera APIs; document the choice.

Create:
- App entry point
- dependency container
- actor-based camera session owner
- model types for camera/lens/capture format/audio/stream/orientation
- feature flags/capability model
- logging subsystem using `os.Logger`
- settings store using AppStorage/UserDefaults or SwiftData where justified
- preview/navigation shell
- test target

Create a `NDIBackend` protocol and `MockNDIBackend` immediately so the rest of the app can compile before the real SDK is installed.

Do not implement fake NDI encoding. The mock should only simulate state and metrics.
