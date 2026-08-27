# Prompt 04 — NDI integration

Integrate the exact official NDI SDK supplied locally by the developer.

First inspect the installed SDK headers/framework/module map and identify the exact APIs available for:
- library initialization/shutdown
- sender creation/destruction
- source naming/groups
- video frame sending
- audio frame sending
- timestamps
- metadata
- tally/remote control if available
- send format capabilities

Create:
- `NDISender.swift`
- `NDIBackend.swift`
- `NDIVideoPipeline.swift`
- `NDIAudioPipeline.swift`
- `NDIConfiguration.swift`
- `NDIStatistics.swift`
- a minimal C/Swift interop wrapper if Swift cannot safely call the C API directly

Support a capability-driven format layer. If the installed standard SDK does not provide a desired native encoding mode, do not fake it; expose the limitation and document that NDI Advanced/licensing may be required.

Implement backpressure and frame dropping policy. The camera pipeline must not stall because the network sender is slower.

Add optional tally/metadata support only when the actual SDK exposes it.
