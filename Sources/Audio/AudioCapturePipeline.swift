// AudioCapturePipeline.swift
// Audio — Real-time audio capture pipeline using AVAudioEngine and input node tap.

import Foundation
import AVFoundation
import CoreMedia
import Domain
import os

// MARK: - Audio Capture Pipeline

/// Production capture pipeline managing AVAudioEngine, real-time tap ingestion,
/// DSP processing (gain/mute/metering), timestamp synchronization, and frame dispatch.
public final class AudioCapturePipeline: @unchecked Sendable {

    // MARK: - Components

    private let engine = AVAudioEngine()
    private let timeSynchronizer = AudioTimeSynchronizer()
    private let bufferConverter = AudioBufferConverter()
    private let logger = Logger(subsystem: "com.tamandicam", category: "AudioCapturePipeline")

    // MARK: - Synchronization & State

    private let lock = NSLock()
    private var _gain: Float = 1.0
    private var _isMuted: Bool = false
    private var _latestLevels: AudioLevelsSnapshot = .silence
    private var _isRunning: Bool = false

    /// Continuation for the AsyncStream of captured audio frames.
    private var frameContinuation: AsyncStream<AudioFrame>.Continuation?

    // MARK: - Public State Accessors

    public var gain: Float {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _gain
        }
        set {
            lock.lock()
            _gain = newValue
            lock.unlock()
        }
    }

    public var isMuted: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isMuted
        }
        set {
            lock.lock()
            _isMuted = newValue
            lock.unlock()
        }
    }

    public var latestLevels: AudioLevelsSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return _latestLevels
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isRunning
    }

    // MARK: - Initialization

    public init() {}

    deinit {
        stop()
    }

    // MARK: - Pipeline Control

    /// Starts the AVAudioEngine capture pipeline and attaches the audio tap.
    ///
    /// - Parameters:
    ///   - continuation: The stream continuation to receive `AudioFrame` instances.
    ///   - bufferSize: Requested PCM buffer size per tap callback (default 1024 frames).
    public func start(
        continuation: AsyncStream<AudioFrame>.Continuation,
        bufferSize: AVAudioFrameCount = 1024
    ) throws {
        lock.lock()
        guard !_isRunning else {
            lock.unlock()
            return
        }
        self.frameContinuation = continuation
        lock.unlock()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioError.engineStartFailed(reason: "Invalid input format (sample rate or channel count is zero)")
        }

        logger.info("Installing audio tap (Format: \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) ch)")

        // Remove any previous tap
        inputNode.removeTap(onBus: 0)

        // Install new tap
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            guard let self else { return }
            self.processCapturedBuffer(buffer: buffer, time: time)
        }

        do {
            try engine.start()
            lock.lock()
            _isRunning = true
            lock.unlock()
            logger.info("AVAudioEngine capture started")
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioError.engineStartFailed(reason: error.localizedDescription)
        }
    }

    /// Stops the AVAudioEngine and cleans up the tap.
    public func stop() {
        lock.lock()
        guard _isRunning else {
            lock.unlock()
            return
        }
        _isRunning = false
        _latestLevels = .silence
        let continuation = frameContinuation
        frameContinuation = nil
        lock.unlock()

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        continuation?.finish()
        logger.info("AVAudioEngine capture stopped")
    }

    // MARK: - Real-Time Processing Callback

    private func processCapturedBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        lock.lock()
        let currentGain = _gain
        let currentMuted = _isMuted
        lock.unlock()

        // 1. DSP Processing: Apply software gain and/or mute, calculate levels
        let levels = AudioDSPProcessor.process(buffer: buffer, gain: currentGain, isMuted: currentMuted)

        lock.lock()
        _latestLevels = levels
        let continuation = frameContinuation
        let running = _isRunning
        lock.unlock()

        guard running, let continuation else { return }

        // 2. Synchronize timestamps with host time clock
        let (presentationTime, timecodeMicros) = timeSynchronizer.synchronize(
            audioTime: time,
            fallbackSampleRate: buffer.format.sampleRate
        )

        // 3. Convert AVAudioPCMBuffer into standard CMSampleBuffer
        do {
            let sampleBuffer = try bufferConverter.convertToCMSampleBuffer(
                pcmBuffer: buffer,
                presentationTime: presentationTime
            )

            // 4. Construct AudioFrame
            let frame = AudioFrame(
                sampleBuffer: sampleBuffer,
                timestamp: presentationTime,
                timecodeMicros: timecodeMicros,
                sampleRate: buffer.format.sampleRate,
                channelCount: Int(buffer.format.channelCount),
                frameCount: Int(buffer.frameLength)
            )

            // 5. Yield to non-blocking async stream
            continuation.yield(frame)
        } catch {
            logger.error("Audio buffer conversion error: \(error.localizedDescription)")
        }
    }
}
