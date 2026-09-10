// CameraPreviewView.swift
// UI — UIKit representable wrapping AVCaptureVideoPreviewLayer for zero-copy camera preview.

import SwiftUI
import AVFoundation
import Camera
import Domain

/// A SwiftUI view that renders camera preview using AVCaptureVideoPreviewLayer.
/// Directly binds to the AVCaptureSession with zero extra memory copies.
public struct CameraPreviewView: UIViewRepresentable {

    private let cameraEngine: CameraEngine?
    private let displayMode: DisplayMode

    public init(cameraEngine: CameraEngine?, displayMode: DisplayMode = .normal) {
        self.cameraEngine = cameraEngine
        self.displayMode = displayMode
    }

    public func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        context.coordinator.previewView = view

        if let engine = cameraEngine {
            Task { @MainActor in
                let session = await engine.getCaptureSession()
                view.setSession(session)
            }
        }
        return view
    }

    public func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.applyDisplayMode(displayMode)

        if let engine = cameraEngine, uiView.currentSession == nil {
            Task { @MainActor in
                let session = await engine.getCaptureSession()
                uiView.setSession(session)
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator: NSObject {
        weak var previewView: PreviewUIView?
    }
}

// MARK: - Preview UIKit View

public final class PreviewUIView: UIView {

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private(set) var currentSession: AVCaptureSession?
    private let dimOverlay = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = .black
        dimOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        dimOverlay.isUserInteractionEnabled = false
        dimOverlay.isHidden = true
        addSubview(dimOverlay)
    }

    func setSession(_ session: AVCaptureSession) {
        guard currentSession !== session else { return }
        currentSession = session

        previewLayer?.removeFromSuperlayer()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.insertSublayer(layer, at: 0)
        self.previewLayer = layer
    }

    func applyDisplayMode(_ mode: DisplayMode) {
        switch mode {
        case .normal:
            previewLayer?.isHidden = false
            dimOverlay.isHidden = true
        case .dimmed:
            previewLayer?.isHidden = false
            dimOverlay.isHidden = false
            dimOverlay.alpha = 0.8
        case .blacked:
            // Blackout: hide preview layer to save GPU/display power while capture continues in background
            previewLayer?.isHidden = true
            dimOverlay.isHidden = false
            dimOverlay.alpha = 1.0
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
        dimOverlay.frame = bounds
    }
}
