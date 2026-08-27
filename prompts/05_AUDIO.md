# Prompt 05 — Audio engine

Implement a low-latency audio subsystem using AVAudioSession and AVAudioEngine/AVCaptureAudioDataOutput as appropriate.

Features:
- microphone route discovery
- built-in mic selection where iOS exposes it
- Bluetooth/USB route awareness
- sample-rate configuration when supported
- channel count discovery
- mute
- gain control only when the hardware/API permits it
- route-change notifications
- interruption handling
- synchronized audio timestamps for NDI

Never claim that iOS can arbitrarily select a physical microphone capsule if the OS does not expose that control.
