# Prompt 06 — LAN browser remote control

Build a native local HTTP + WebSocket controller.

Use Network.framework where practical. Advertise the service over Bonjour.

Endpoints:
GET /api/v1/status
GET /api/v1/capabilities
GET /api/v1/cameras
GET /api/v1/formats
GET /api/v1/settings
POST /api/v1/stream/start
POST /api/v1/stream/stop
POST /api/v1/camera/select
POST /api/v1/camera/zoom
POST /api/v1/camera/focus
POST /api/v1/camera/exposure
POST /api/v1/torch
POST /api/v1/video
POST /api/v1/audio
POST /api/v1/orientation
POST /api/v1/display
POST /api/v1/preset/load

WebSocket `/ws` broadcasts state changes and metrics.

Security:
- pairing code displayed in app
- exchange for a random bearer token
- token stored only on the phone
- revoke all sessions
- rate limit commands
- bind to LAN interfaces only unless user explicitly enables another mode
- never log tokens

Serve a responsive controller from bundled HTML/CSS/JS assets. The browser UI must work on desktop and tablet.
