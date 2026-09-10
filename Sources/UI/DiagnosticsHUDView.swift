// DiagnosticsHUDView.swift
// UI — Broadcast overlay displaying real-time stream and device telemetry.

import SwiftUI
import Domain

/// Compact telemetry HUD displaying real-time stream diagnostics.
public struct DiagnosticsHUDView: View {

    let captureFPS: Double
    let outputFPS: Double
    let bitrateMbps: Double
    let droppedFrames: UInt64
    let videoQueueDepth: Int
    let thermalState: ThermalState
    let activeFormat: String?

    public init(
        captureFPS: Double = 60.0,
        outputFPS: Double = 60.0,
        bitrateMbps: Double = 120.0,
        droppedFrames: UInt64 = 0,
        videoQueueDepth: Int = 0,
        thermalState: ThermalState = .nominal,
        activeFormat: String? = "1080p60"
    ) {
        self.captureFPS = captureFPS
        self.outputFPS = outputFPS
        self.bitrateMbps = bitrateMbps
        self.droppedFrames = droppedFrames
        self.videoQueueDepth = videoQueueDepth
        self.thermalState = thermalState
        self.activeFormat = activeFormat
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                telemetryItem(label: "FPS", value: String(format: "%.1f", outputFPS))
                telemetryItem(label: "BITRATE", value: String(format: "%.1fM", bitrateMbps))
                telemetryItem(label: "DROP", value: "\(droppedFrames)", isAlert: droppedFrames > 0)
                telemetryItem(label: "Q", value: "\(videoQueueDepth)", isAlert: videoQueueDepth > 2)
                thermalIndicator
            }
            if let format = activeFormat {
                Text(format)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func telemetryItem(label: String, value: String, isAlert: Bool = false) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(isAlert ? .red : .white)
        }
    }

    private var thermalIndicator: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(thermalColor)
                .frame(width: 6, height: 6)
            Text(thermalState.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(thermalColor)
        }
    }

    private var thermalColor: Color {
        switch thermalState {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        }
    }
}
