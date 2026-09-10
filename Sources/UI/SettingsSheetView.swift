// SettingsSheetView.swift
// UI — Settings sheet for configuring video, audio, NDI, presets, and display behavior.

import SwiftUI
import Domain

/// Settings sheet allowing users to customize stream, device, NDI, and remote settings.
public struct SettingsSheetView: View {

    @Binding var resolution: String
    @Binding var targetFPS: Double
    @Binding var stabilizationMode: StabilizationMode
    @Binding var audioMuted: Bool
    @Binding var audioGain: Float
    @Binding var ndiSourceName: String
    @Binding var ndiGroup: String
    @Binding var displayMode: DisplayMode
    @Binding var isOrientationLocked: Bool
    @Binding var remoteServerPort: UInt16

    let onApplyPreset: (Preset) -> Void
    let onResetDefaults: () -> Void
    @Environment(\.dismiss) private var dismiss

    public init(
        resolution: Binding<String>,
        targetFPS: Binding<Double>,
        stabilizationMode: Binding<StabilizationMode>,
        audioMuted: Binding<Bool>,
        audioGain: Binding<Float>,
        ndiSourceName: Binding<String>,
        ndiGroup: Binding<String>,
        displayMode: Binding<DisplayMode>,
        isOrientationLocked: Binding<Bool>,
        remoteServerPort: Binding<UInt16>,
        onApplyPreset: @escaping (Preset) -> Void = { _ in },
        onResetDefaults: @escaping () -> Void = {}
    ) {
        self._resolution = resolution
        self._targetFPS = targetFPS
        self._stabilizationMode = stabilizationMode
        self._audioMuted = audioMuted
        self._audioGain = audioGain
        self._ndiSourceName = ndiSourceName
        self._ndiGroup = ndiGroup
        self._displayMode = displayMode
        self._isOrientationLocked = isOrientationLocked
        self._remoteServerPort = remoteServerPort
        self.onApplyPreset = onApplyPreset
        self.onResetDefaults = onResetDefaults
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Video Configuration
                Section("Video Settings") {
                    Picker("Resolution", selection: $resolution) {
                        Text("4K (3840×2160)").tag("3840x2160")
                        Text("1080p (1920×1080)").tag("1920x1080")
                        Text("720p (1280×720)").tag("1280x720")
                    }

                    Picker("Frame Rate", selection: $targetFPS) {
                        Text("24 fps").tag(24.0)
                        Text("30 fps").tag(30.0)
                        Text("60 fps").tag(60.0)
                        Text("120 fps").tag(120.0)
                    }

                    Picker("Stabilization", selection: $stabilizationMode) {
                        Text("Off").tag(StabilizationMode.off)
                        Text("Standard").tag(StabilizationMode.standard)
                        Text("Cinematic").tag(StabilizationMode.cinematic)
                        Text("Cinematic Extended").tag(StabilizationMode.cinematicExtended)
                    }

                    Toggle("Lock Orientation", isOn: $isOrientationLocked)
                }

                // Audio Configuration
                Section("Audio Settings") {
                    Toggle("Mute Audio", isOn: $audioMuted)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Gain")
                            Spacer()
                            Text(String(format: "%.1f", audioGain))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $audioGain, in: 0.0...2.0, step: 0.05)
                    }
                }

                // NDI Configuration
                Section("NDI Stream Settings") {
                    HStack {
                        Text("Source Name")
                        TextField("TamaNDI", text: $ndiSourceName)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("NDI Group")
                        TextField("Default", text: $ndiGroup)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Display & Power
                Section("Display & Power") {
                    Picker("Display Mode", selection: $displayMode) {
                        Text("Normal").tag(DisplayMode.normal)
                        Text("Dimmed (Save Battery)").tag(DisplayMode.dimmed)
                        Text("Blackout (Live Stream)").tag(DisplayMode.blacked)
                    }
                    .pickerStyle(.segmented)

                    Text("Capture and NDI transmission continue uninterrupted in all display modes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Built-in Presets
                Section("Quick Presets") {
                    ForEach(PresetTemplate.allCases) { template in
                        Button {
                            let p = Preset(
                                id: template.rawValue,
                                name: template.displayName,
                                template: template,
                                isBuiltIn: true,
                                settings: PresetSettings(resolution: resolution, fps: targetFPS)
                            )
                            onApplyPreset(p)
                        } label: {
                            HStack {
                                Text(template.displayName)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                // Reset
                Section {
                    Button("Reset to Defaults", role: .destructive, action: onResetDefaults)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
