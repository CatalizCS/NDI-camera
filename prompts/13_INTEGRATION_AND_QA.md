# Prompt 13 — Final integration, build, and QA

Now integrate all previous modules into one coherent app.

Acceptance criteria:
1. App launches and shows camera permission flow.
2. Camera capability list is generated from the actual device.
3. Single-camera preview works.
4. Dual/triple modes only appear when supported.
5. Resolution/FPS selectors only contain valid combinations.
6. Stabilization only shows supported modes.
7. Torch is disabled when unavailable.
8. Audio route is displayed accurately.
9. NDI sender uses the exact installed SDK API, or mock mode is clearly labeled when SDK is absent.
10. Browser controller is discoverable over Bonjour.
11. Pairing is required before control.
12. Browser changes update the phone immediately.
13. Phone changes update browser through WebSocket.
14. Stream start/stop is idempotent.
15. Capture interruptions recover gracefully.
16. Thermal/memory pressure produces safe behavior.
17. No UI operation blocks capture.
18. No proprietary NDI API is fabricated.
19. All tests pass.
20. Produce `SETUP.md`, `NDI_SDK_SETUP.md`, `ARCHITECTURE.md`, and `TROUBLESHOOTING.md`.

At the end, provide exact Xcode build steps and a list of any SDK-specific manual actions that cannot be automated.
