# Prompt 09 — Presets and persistence

Implement user presets:
- Streaming 1080p60
- Streaming 4K30
- Low bandwidth
- High quality
- Dual camera
- Triple composite
- Custom

Presets must be capability-aware. Loading a preset on a different iPhone should automatically downgrade unsupported settings and show a warning.

Allow JSON export/import of non-secret configuration. Never export pairing tokens by default.
