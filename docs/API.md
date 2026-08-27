# TamaNDI Remote API Contract

All responses are JSON and include `ok: true/false`.

Example command:
```json
{"camera":"wide"}
```

Example WebSocket event:
```json
{"type":"state","payload":{"streaming":true,"fps":59.94}}
```

The final implementation must generate an OpenAPI document from the actual route definitions rather than maintaining two conflicting schemas.
