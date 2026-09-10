// ContentView.swift
// UI — Root view assembling camera preview, broadcast overlay, HUD, and modal sheets.

import SwiftUI
import Domain

/// Primary screen of the TamaNDI camera application.
public struct ContentView: View {

    @Environment(AppCoordinator.self) private var coordinator

    @State private var showSettings = false
    @State private var showPairing = false
    @State private var showHUD = true
    @State private var selectedLens = "1x"
    @State private var currentZoom: Double = 1.0

    // Settings bindings
    @State private var resolution: String = "1920x1080"
    @State private var targetFPS: Double = 60.0
    @State private var stabilizationMode: StabilizationMode = .standard
    @State private var audioMuted: Bool = false
    @State private var audioGain: Float = 1.0
    @State private var ndiSourceName: String = "TamaNDI"
    @State private var ndiGroup: String = ""
    @State private var isOrientationLocked: Bool = false
    @State private var remoteServerPort: UInt16 = 5353

    public init() {}

    public var body: some View {
        ZStack {
            // Base background
            Color.black.ignoresSafeArea()

            // Zero-copy camera preview
            CameraPreviewView(
                cameraEngine: coordinator.cameraEngine,
                displayMode: coordinator.displayMode
            )
            .ignoresSafeArea()

            // Diagnostics HUD (top-left)
            if showHUD && coordinator.displayMode != .blacked {
                VStack {
                    HStack {
                        DiagnosticsHUDView(
                            captureFPS: coordinator.cameraState.targetFPS,
                            outputFPS: coordinator.isStreaming ? 60.0 : 0.0,
                            bitrateMbps: coordinator.isStreaming ? 125.0 : 0.0,
                            droppedFrames: 0,
                            videoQueueDepth: 0,
                            thermalState: coordinator.thermalState,
                            activeFormat: "\(resolution)@\(Int(targetFPS))"
                        )
                        Spacer()
                    }
                    .padding(.leading, 16)
                    .padding(.top, 56)
                    Spacer()
                }
            }

            // Controls Overlay (floating on top)
            if coordinator.displayMode != .blacked {
                ControlsOverlayView(
                    isStreaming: coordinator.isStreaming,
                    streamState: coordinator.streamState,
                    currentZoom: currentZoom,
                    isTorchActive: coordinator.cameraState.isTorchActive,
                    tallyProgram: coordinator.isStreaming,
                    tallyPreview: false,
                    showHUD: showHUD,
                    availableLenses: ["0.5x", "1x", "3x", "5x"],
                    selectedLens: selectedLens,
                    onToggleStream: {
                        Task { await coordinator.toggleStream() }
                    },
                    onSelectLens: { lens in
                        selectedLens = lens
                        let factor: Double = switch lens {
                        case "0.5x": 0.5
                        case "1x": 1.0
                        case "3x": 3.0
                        case "5x": 5.0
                        default: 1.0
                        }
                        currentZoom = factor
                        Task { await coordinator.setZoom(factor) }
                    },
                    onChangeZoom: { zoom in
                        currentZoom = zoom
                        Task { await coordinator.setZoom(zoom) }
                    },
                    onToggleTorch: {
                        let newState = !coordinator.cameraState.isTorchActive
                        Task { await coordinator.setTorch(enabled: newState) }
                    },
                    onToggleHUD: {
                        showHUD.toggle()
                    },
                    onOpenSettings: {
                        showSettings = true
                    },
                    onOpenPairing: {
                        showPairing = true
                    }
                )
            }

            // Blackout touch-to-wake banner
            if coordinator.displayMode == .blacked {
                VStack {
                    Spacer()
                    Button {
                        coordinator.setDisplayMode(.normal)
                    } label: {
                        Text("TAP TO EXIT BLACKOUT")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 32)
                }
            }

            // Broadcast Tally Frame Border
            if coordinator.isStreaming {
                Rectangle()
                    .strokeBorder(Color.red, lineWidth: 3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView(
                resolution: $resolution,
                targetFPS: $targetFPS,
                stabilizationMode: $stabilizationMode,
                audioMuted: $audioMuted,
                audioGain: $audioGain,
                ndiSourceName: $ndiSourceName,
                ndiGroup: $ndiGroup,
                displayMode: Binding(
                    get: { coordinator.displayMode },
                    set: { coordinator.setDisplayMode($0) }
                ),
                isOrientationLocked: $isOrientationLocked,
                remoteServerPort: $remoteServerPort,
                onApplyPreset: { preset in
                    if let res = preset.settings.resolution { resolution = res }
                    if let fps = preset.settings.fps { targetFPS = fps }
                },
                onResetDefaults: {
                    resolution = "1920x1080"
                    targetFPS = 60.0
                    stabilizationMode = .standard
                    audioMuted = false
                    audioGain = 1.0
                    ndiSourceName = "TamaNDI"
                    ndiGroup = ""
                    coordinator.setDisplayMode(.normal)
                }
            )
        }
        .sheet(isPresented: $showPairing) {
            PairingCodeSheetView(
                pairingCode: coordinator.pairingCode ?? "849201",
                serverPort: remoteServerPort,
                onRegenerate: {
                    Task {
                        // Request new pairing code from coordinator
                        coordinator.pairingCode = String(format: "%06d", Int.random(in: 100000...999999))
                    }
                },
                onRevokeAll: {
                    Task {
                        coordinator.pairingCode = nil
                    }
                }
            )
        }
    }
}
