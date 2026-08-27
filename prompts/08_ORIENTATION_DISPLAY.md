# Prompt 08 — Orientation and display behavior

Implement orientation policy independently from UI orientation.

Modes:
- auto
- portrait
- landscape left
- landscape right

Support orientation lock so the NDI output stays stable even if the phone rotates.

Add display controls:
- keep-awake while streaming
- dim preview
- black preview while streaming

Do not claim that an iOS app can turn off the physical display while continuing camera capture in the background. Implement foreground blackout/dimming safely and document iOS lifecycle limitations.
