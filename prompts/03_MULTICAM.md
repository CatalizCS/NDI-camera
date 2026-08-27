# Prompt 03 — Single / Dual / Triple camera

Implement multi-camera support using `AVCaptureMultiCamSession`.

Modes:
1. Single
2. Dual independent
3. Dual composite
4. Triple independent
5. Triple composite

Rules:
- verify `isMultiCamSupported`
- calculate viable device combinations dynamically
- use supported hardware connections only
- gracefully reject unsupported combinations
- avoid exceeding camera resource budgets
- allow each camera feed to be previewed
- composite feeds with Core Image/Metal only if necessary and without blocking capture queues
- maintain stable timestamps
- expose a capability matrix to the UI

For independent mode, create distinct NDI sender instances/names. For composite mode, create one composed frame and one NDI source.

Do not promise triple capture on hardware that cannot do it.
