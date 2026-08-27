# Prompt 11 — Testing

Create:
- unit tests for capability filtering
- unit tests for REST command decoding
- unit tests for preset downgrade logic
- unit tests for pairing/token expiry
- integration tests around mock NDI backend
- UI tests for stream start/stop, camera selection, settings navigation, and pairing

The test suite must run without physical camera hardware by using mocks for camera/NDI/network layers.

Add a hardware test checklist for real-device validation:
- single lens
- dual capture
- triple capture where supported
- 4K30/4K60 where supported
- 1080p60/120/240 where supported
- torch
- stabilization
- audio route changes
- thermal throttling
- Wi-Fi congestion
- app interruption
