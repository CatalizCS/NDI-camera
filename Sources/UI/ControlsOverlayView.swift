// ControlsOverlayView.swift
// UI — Broadcast overlay controls for camera switching, zoom, torch, tally, and stream toggle.

import SwiftUI
import Domain

/// Interactive controls overlay floating above the camera preview.
public struct ControlsOverlayView: View {

    let isStreaming: Bool
    let streamState: StreamState
    let currentZoom: Double
    let isTorchActive: Bool
    let tallyProgram: Bool
    let tallyPreview: Bool
    let showHUD: Bool
    let availableLenses: [String]
    let selectedLens: String

    let onToggleStream: () -> Void
    let onSelectLens: (String) -> Void
    let onChangeZoom: (Double) -> Void
    let onToggleTorch: () -> Void
    let onToggleHUD: () -> Void
    let onOpenSettings: () -> Void
    let onOpenPairing: () -> Void

    public init(
        isStreaming: Bool,
        streamState: StreamState,
        currentZoom: Double = 1.0,
        isTorchActive: Bool = false,
        tallyProgram: Bool = false,
        tallyPreview: Bool = false,
        showHUD: Bool = true,
        availableLenses: [String] = ["0.5x", "1x", "3x"],
        selectedLens: String = "1x",
        onToggleStream: @escaping () -> Void = {},
        onSelectLens: @escaping (String) -> Void = { _ in },
        onChangeZoom: @escaping (Double) -> Void = { _ in },
        onToggleTorch: @escaping () -> Void = {},
        onToggleHUD: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onOpenPairing: @escaping () -> Void = {}
    ) {
        self.isStreaming = isStreaming
        self.streamState = streamState
        self.currentZoom = currentZoom
        self.isTorchActive = isTorchActive
        self.tallyProgram = tallyProgram
        self.tallyPreview = tallyPreview
        self.showHUD = showHUD
        self.availableLenses = availableLenses
        self.selectedLens = selectedLens
        self.onToggleStream = onToggleStream
        self.onSelectLens = onSelectLens
        self.onChangeZoom = onChangeZoom
        self.onToggleTorch = onToggleTorch
        self.onToggleHUD = onToggleHUD
        self.onOpenSettings = onOpenSettings
        self.onOpenPairing = onOpenPairing
    }

    public var body: some View {
        VStack {
            // Top Bar
            HStack(spacing: 12) {
                // Tally Status Indicator
                tallyBadge

                Spacer()

                // Stream Button
                Button(action: onToggleStream) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isStreaming ? Color.red : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(streamButtonTitle)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(isStreaming ? Color.red.opacity(0.85) : Color.black.opacity(0.6))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }

                // HUD Toggle
                controlButton(systemName: showHUD ? "chart.xyaxis.line" : "chart.line.uptrend.xyaxis") {
                    onToggleHUD()
                }

                // Remote Pairing
                controlButton(systemName: "antenna.radiowaves.left.and.right") {
                    onOpenPairing()
                }

                // Settings
                controlButton(systemName: "gearshape") {
                    onOpenSettings()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            // Bottom Bar
            VStack(spacing: 16) {
                // Lens Switcher Pills
                HStack(spacing: 10) {
                    ForEach(availableLenses, id: \.self) { lens in
                        Button {
                            onSelectLens(lens)
                        } label: {
                            Text(lens)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .frame(width: 44, height: 44)
                                .background(selectedLens == lens ? Color.yellow : Color.black.opacity(0.6))
                                .foregroundStyle(selectedLens == lens ? Color.black : Color.white)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }

                    // Torch Quick Toggle
                    Button(action: onToggleTorch) {
                        Image(systemName: isTorchActive ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(isTorchActive ? Color.yellow : Color.black.opacity(0.6))
                            .foregroundStyle(isTorchActive ? Color.black : Color.white)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var tallyBadge: some View {
        HStack(spacing: 4) {
            if tallyProgram {
                Text("PGM")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else if tallyPreview {
                Text("PVW")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text("STANDBY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.6))
                    .foregroundStyle(.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private var streamButtonTitle: String {
        switch streamState {
        case .idle: "LIVE"
        case .starting: "STARTING"
        case .streaming: "ON AIR"
        case .stopping: "STOPPING"
        case .error: "ERROR"
        }
    }

    private func controlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.6))
                .foregroundStyle(.white)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}
