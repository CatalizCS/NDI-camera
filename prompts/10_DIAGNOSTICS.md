# Prompt 10 — Diagnostics and performance

Implement an in-app diagnostics screen.

Metrics:
- capture FPS
- output FPS
- dropped frames
- video queue depth
- audio queue depth
- current bitrate
- NDI send latency if exposed by SDK
- memory footprint
- thermal state
- camera exposure/focus state
- active format
- audio route
- network interface information that is safe to expose

Use `os_signpost` for critical pipeline sections.

Add an optional diagnostics JSON export excluding secrets.
