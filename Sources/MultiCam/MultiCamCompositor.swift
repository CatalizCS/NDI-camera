// MultiCamCompositor.swift
// MultiCam — Zero-allocation Metal/CoreImage CVPixelBuffer layout rendering engine.
// Composes multiple synchronized camera feeds into a single unified stream without UIImage conversion.

import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
import Domain
import Metal
import os

// MARK: - MultiCam Compositor

/// High-performance composite frame renderer backed by Metal and CVPixelBufferPool.
public final class MultiCamCompositor: @unchecked Sendable {

    // MARK: - Properties

    /// CoreImage rendering context backed by the system Metal device.
    private let ciContext: CIContext

    /// Dedicated Metal command queue if available.
    private let metalDevice: MTLDevice?

    /// Pixel buffer pool for zero-allocation output buffer recycling.
    private var pixelBufferPool: CVPixelBufferPool?

    /// Current target resolution configured on the buffer pool.
    private var currentPoolResolution: Resolution?

    /// Current pixel format type.
    private let pixelFormat: OSType

    /// Lock protecting pool reallocation.
    private let lock = NSLock()

    /// Logger for rendering telemetry.
    private let logger = Logger(subsystem: "com.tamandicam", category: "MultiCamCompositor")

    // MARK: - Initialization

    public init(pixelFormat: OSType = kCVPixelFormatType_32BGRA) {
        self.pixelFormat = pixelFormat

        if let device = MTLCreateSystemDefaultDevice() {
            self.metalDevice = device
            self.ciContext = CIContext(
                mtlDevice: device,
                options: [
                    .workingColorSpace: NSNull(),
                    .outputColorSpace: NSNull(),
                    .useSoftwareRenderer: false
                ]
            )
        } else {
            self.metalDevice = nil
            self.ciContext = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        }
    }

    // MARK: - Public API

    /// Composes a synchronized set of camera frames according to the specified layout.
    /// Returns a retained `CVPixelBuffer` containing the rendered composite frame.
    public func composite(
        frameSet: SynchronizedFrameSet,
        layout: CompositeLayout,
        targetResolution: Resolution
    ) throws -> CVPixelBuffer {
        // Obtain a reusable pixel buffer from the pool
        let outputBuffer = try getOrCreatePixelBuffer(for: targetResolution)

        let targetWidth = Double(targetResolution.width)
        let targetHeight = Double(targetResolution.height)
        let targetRect = CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)

        let activeSlots = Array(frameSet.frames.keys)
        let viewports = layout.viewports(for: activeSlots)

        var compositeCIImage: CIImage?

        // Order slots: Primary is background, secondary/tertiary are foreground overlays
        let sortedSlots: [MultiCamSlot] = activeSlots.sorted {
            if $0 == .primary { return true }
            if $1 == .primary { return false }
            return $0.index < $1.index
        }

        for slot in sortedSlots {
            guard let sampleFrame = frameSet.frames[slot],
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleFrame.sampleBuffer),
                  let normRect = viewports[slot] else {
                continue
            }

            let sourceCI = CIImage(cvPixelBuffer: pixelBuffer)
            let srcExtent = sourceCI.extent
            guard srcExtent.width > 0, srcExtent.height > 0 else { continue }

            // Compute target pixel coordinates (CoreImage origin is bottom-left)
            let dstX = normRect.x * targetWidth
            let dstW = normRect.width * targetWidth
            let dstH = normRect.height * targetHeight
            // Invert normalized Y because CoreImage origin is bottom-left whereas NormalizedRect origin is top-left
            let dstY = targetHeight - (normRect.y * targetHeight) - dstH

            // Scale to fill destination rect
            let scaleX = dstW / srcExtent.width
            let scaleY = dstH / srcExtent.height

            let transform = CGAffineTransform(translationX: -srcExtent.origin.x, y: -srcExtent.origin.y)
                .concatenating(CGAffineTransform(scaleX: scaleX, y: scaleY))
                .concatenating(CGAffineTransform(translationX: dstX, y: dstY))

            let transformedImage = sourceCI.transformed(by: transform).cropped(to: CGRect(x: dstX, y: dstY, width: dstW, height: dstH))

            if let existing = compositeCIImage {
                compositeCIImage = transformedImage.composited(over: existing)
            } else {
                compositeCIImage = transformedImage
            }
        }

        guard let finalImage = compositeCIImage else {
            throw MultiCamError.compositionFailed(reason: "No valid image buffers to render")
        }

        // Render into destination CVPixelBuffer
        ciContext.render(finalImage, to: outputBuffer, bounds: targetRect, colorSpace: nil)

        return outputBuffer
    }

    /// Helper to convert a composited `CVPixelBuffer` into a ready `CMSampleBuffer`.
    public func makeSampleBuffer(
        from pixelBuffer: CVPixelBuffer,
        timestamp: CMTime
    ) throws -> CMSampleBuffer {
        var formatDesc: CMVideoFormatDescription?
        let descStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDesc
        )
        guard descStatus == noErr, let fd = formatDesc else {
            throw MultiCamError.compositionFailed(reason: "Failed to create format description: \(descStatus)")
        }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: timestamp,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let sbStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: fd,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard sbStatus == noErr, let sb = sampleBuffer else {
            throw MultiCamError.compositionFailed(reason: "Failed to create sample buffer from pixel buffer: \(sbStatus)")
        }

        return sb
    }

    // MARK: - Private Buffer Pool

    private func getOrCreatePixelBuffer(for resolution: Resolution) throws -> CVPixelBuffer {
        lock.lock()
        defer { lock.unlock() }

        if pixelBufferPool == nil || currentPoolResolution != resolution {
            createPixelBufferPool(width: resolution.width, height: resolution.height)
            currentPoolResolution = resolution
        }

        guard let pool = pixelBufferPool else {
            throw MultiCamError.compositionFailed(reason: "Pixel buffer pool unavailable")
        }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        guard status == kCVReturnSuccess, let pb = pixelBuffer else {
            throw MultiCamError.compositionFailed(reason: "Failed to allocate pixel buffer from pool (code: \(status))")
        }

        return pb
    }

    private func createPixelBufferPool(width: Int, height: Int) {
        let poolAttributes: [CFString: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey: 3
        ]

        let pixelBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormat,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey: true
        ]

        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )

        if status == kCVReturnSuccess {
            self.pixelBufferPool = pool
            logger.info("Allocated CVPixelBufferPool for \(width)×\(height)")
        } else {
            logger.error("Failed to allocate CVPixelBufferPool: \(status)")
        }
    }
}
