// PairingCodeSheetView.swift
// UI — Pairing sheet displaying 6-digit code for web remote controller connection.

import SwiftUI
import Domain

/// Sheet displaying the 6-digit code for web remote control pairing.
public struct PairingCodeSheetView: View {

    let pairingCode: String
    let serverPort: UInt16
    let onRegenerate: () -> Void
    let onRevokeAll: () -> Void
    @Environment(\.dismiss) private var dismiss

    public init(
        pairingCode: String,
        serverPort: UInt16 = 5353,
        onRegenerate: @escaping () -> Void = {},
        onRevokeAll: @escaping () -> Void = {}
    ) {
        self.pairingCode = pairingCode
        self.serverPort = serverPort
        self.onRegenerate = onRegenerate
        self.onRevokeAll = onRevokeAll
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text("Remote Control Pairing")
                        .font(.title2.bold())

                    Text("Open the web controller on your browser to control this camera over the local network.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    Text("PAIRING CODE")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(Array(pairingCode.enumerated()), id: \.offset) { _, char in
                            Text(String(char))
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .frame(width: 44, height: 56)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                    }

                    Text("Valid for 5 minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

                VStack(spacing: 8) {
                    Text("Port: \(serverPort)  •  Bonjour: _tamandicam._tcp.")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: onRegenerate) {
                        Label("Generate New Code", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive, action: onRevokeAll) {
                        Label("Disconnect All Clients", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .padding(.top, 24)
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
