# Prompt 07 — Browser controller UI

Create a polished broadcast-style web controller using vanilla TypeScript or modern browser JavaScript bundled into static assets.

Pages/panels:
- Live overview
- Camera
- Video
- Audio
- NDI
- Orientation/Display
- Presets
- Diagnostics

Live overview should show:
- stream status
- source name
- current camera/lens
- resolution/FPS
- measured FPS
- bitrate
- dropped frames
- audio route
- torch
- stabilization
- thermal warning

Use optimistic UI only for controls that can be reconciled against server state. WebSocket updates are authoritative.

Use the provided SVG assets from `/assets` as a starting visual language. Do not copy any third-party app branding.
