//
//  DualVideoEngine.swift
//  Dual Camera
//

import AVFoundation
import CoreImage

/// Owns multi-cam video/audio data outputs and recording.
/// Must stay off the MainActor so sample-buffer callbacks remain real-time.
nonisolated final class DualVideoEngine: NSObject, @unchecked Sendable {
    let backVideoOutput = AVCaptureVideoDataOutput()
    let frontVideoOutput = AVCaptureVideoDataOutput()
    let audioOutput = AVCaptureAudioDataOutput()

    private let backQueue = DispatchQueue(label: "com.dualcamera.dualvideo.back")
    private let frontQueue = DispatchQueue(label: "com.dualcamera.dualvideo.front")
    private let audioQueue = DispatchQueue(label: "com.dualcamera.dualvideo.audio")
    private let backCIContext = CIContext(options: [.useSoftwareRenderer: false])
    private let frontCIContext = CIContext(options: [.useSoftwareRenderer: false])
    private let stateLock = NSLock()

    private(set) var isConfigured = false
    private var recorder: DualVideoRecorder?
    private var isPrimaryBack = true
    private var receivedBackFrames = 0
    private var receivedFrontFrames = 0
    private var receivedAudioBuffers = 0
    private var droppedCopyFailures = 0

    var onRecordingFinished: ((Result<URL, Error>) -> Void)?

    enum EngineError: LocalizedError {
        case cannotAddOutputs
        case alreadyRecording
        case notRecording
        case noFrames
        case writerPrepareFailed(String)

        var errorDescription: String? {
            switch self {
            case .cannotAddOutputs:
                "Unable to attach dual video outputs to the capture session."
            case .alreadyRecording:
                "Recording is already in progress."
            case .notRecording:
                "No active recording."
            case .noFrames:
                "No video frames were captured. Try again."
            case .writerPrepareFailed(let message):
                "Unable to prepare video writer: \(message)"
            }
        }
    }

    func configure(
        session: AVCaptureMultiCamSession,
        backPort: AVCaptureInput.Port,
        frontPort: AVCaptureInput.Port
    ) throws {
        VideoDebugLog.log("configure() begin, hardwareCost=\(session.hardwareCost)")

        backVideoOutput.alwaysDiscardsLateVideoFrames = true
        frontVideoOutput.alwaysDiscardsLateVideoFrames = true
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        backVideoOutput.videoSettings = settings
        frontVideoOutput.videoSettings = settings
        backVideoOutput.setSampleBufferDelegate(self, queue: backQueue)
        frontVideoOutput.setSampleBufferDelegate(self, queue: frontQueue)
        audioOutput.setSampleBufferDelegate(self, queue: audioQueue)

        guard session.canAddOutput(backVideoOutput),
              session.canAddOutput(frontVideoOutput) else {
            VideoDebugLog.log("ERROR canAddOutput failed back=\(session.canAddOutput(backVideoOutput)) front=\(session.canAddOutput(frontVideoOutput))")
            throw EngineError.cannotAddOutputs
        }
        session.addOutputWithNoConnections(backVideoOutput)
        session.addOutputWithNoConnections(frontVideoOutput)

        let backConnection = AVCaptureConnection(inputPorts: [backPort], output: backVideoOutput)
        let frontConnection = AVCaptureConnection(inputPorts: [frontPort], output: frontVideoOutput)
        guard session.canAddConnection(backConnection),
              session.canAddConnection(frontConnection) else {
            VideoDebugLog.log("ERROR canAddConnection failed")
            throw EngineError.cannotAddOutputs
        }
        session.addConnection(backConnection)
        session.addConnection(frontConnection)
        applyPortraitRotation(backConnection)
        applyPortraitRotation(frontConnection)
        if frontConnection.isVideoMirroringSupported {
            frontConnection.automaticallyAdjustsVideoMirroring = false
            frontConnection.isVideoMirrored = true
        }
        backConnection.isEnabled = true
        frontConnection.isEnabled = true

        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
            audioOutput.connections.forEach { $0.isEnabled = true }
            VideoDebugLog.log("audio output added")
        } else {
            VideoDebugLog.log("WARNING audio output not added")
        }

        isConfigured = true
        VideoDebugLog.log("configure() OK, hardwareCost=\(session.hardwareCost), backEnabled=\(backConnection.isEnabled), frontEnabled=\(frontConnection.isEnabled)")
    }

    func reconnectBack(port: AVCaptureInput.Port, session: AVCaptureMultiCamSession) {
        for connection in backVideoOutput.connections {
            session.removeConnection(connection)
        }
        let connection = AVCaptureConnection(inputPorts: [port], output: backVideoOutput)
        guard session.canAddConnection(connection) else {
            VideoDebugLog.log("ERROR reconnectBack canAddConnection failed")
            return
        }
        session.addConnection(connection)
        applyPortraitRotation(connection)
        connection.isEnabled = true
        VideoDebugLog.log("reconnectBack OK")
    }

    func updatePrimaryBack(_ value: Bool) {
        stateLock.lock()
        isPrimaryBack = value
        stateLock.unlock()
        VideoDebugLog.log("primaryBack=\(value)")
    }

    func startRecording(layout: CaptureLayoutContext) throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard recorder == nil else { throw EngineError.alreadyRecording }

        receivedBackFrames = 0
        receivedFrontFrames = 0
        receivedAudioBuffers = 0
        droppedCopyFailures = 0

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        let frameSize = CGSize(width: 1080, height: 1920)
        VideoDebugLog.log("startRecording layout=\(layout.layout) url=\(url.lastPathComponent) size=1080x1920")

        let newRecorder = DualVideoRecorder(
            outputURL: url,
            layoutContext: layout,
            frameSize: frameSize
        )
        do {
            try newRecorder.prepare()
            newRecorder.start()
            recorder = newRecorder
            VideoDebugLog.log("recorder started")
        } catch {
            VideoDebugLog.log("ERROR prepare failed: \(error)")
            throw EngineError.writerPrepareFailed(error.localizedDescription)
        }
    }

    func pauseRecording() {
        stateLock.lock()
        let active = recorder
        stateLock.unlock()
        active?.pause()
        VideoDebugLog.log("engine.pauseRecording")
    }

    func resumeRecording() {
        stateLock.lock()
        let active = recorder
        stateLock.unlock()
        active?.resume()
        VideoDebugLog.log("engine.resumeRecording")
    }

    func stopRecording() {
        stateLock.lock()
        let active = recorder
        let backCount = receivedBackFrames
        let frontCount = receivedFrontFrames
        let audioCount = receivedAudioBuffers
        let copyFails = droppedCopyFailures
        recorder = nil
        stateLock.unlock()

        VideoDebugLog.log("stopRecording received back=\(backCount) front=\(frontCount) audio=\(audioCount) copyFails=\(copyFails)")

        guard let active else {
            VideoDebugLog.log("ERROR stop with no active recorder")
            onRecordingFinished?(.failure(EngineError.notRecording))
            return
        }

        active.stop { [weak self] url in
            if let url {
                VideoDebugLog.log("stopRecording SUCCESS \(url.lastPathComponent)")
                self?.onRecordingFinished?(.success(url))
            } else {
                VideoDebugLog.log("ERROR stopRecording no frames written (callback nil URL)")
                self?.onRecordingFinished?(.failure(EngineError.noFrames))
            }
            // Keep `active` alive until finishWriting callback fires.
            _ = active
        }
    }

    private func applyPortraitRotation(_ connection: AVCaptureConnection) {
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        } else {
            VideoDebugLog.log("WARNING rotation 90 not supported")
        }
    }

    private func copyPixelBuffer(_ source: CVPixelBuffer, using context: CIContext) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        var copy: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            CVPixelBufferGetPixelFormatType(source),
            attrs as CFDictionary,
            &copy
        )
        guard status == kCVReturnSuccess, let copy else {
            return nil
        }
        context.render(CIImage(cvPixelBuffer: source), to: copy)
        return copy
    }
}

extension DualVideoEngine: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        stateLock.lock()
        let active = recorder
        let primaryBack = isPrimaryBack
        stateLock.unlock()
        guard let active else { return }

        if output === audioOutput {
            stateLock.lock()
            receivedAudioBuffers += 1
            let count = receivedAudioBuffers
            stateLock.unlock()
            if count == 1 || count % 50 == 0 {
                VideoDebugLog.log("audio buffer #\(count)")
            }
            active.appendAudio(sampleBuffer)
            return
        }

        let isBack = output === backVideoOutput
        stateLock.lock()
        if isBack {
            receivedBackFrames += 1
        } else {
            receivedFrontFrames += 1
        }
        let backCount = receivedBackFrames
        let frontCount = receivedFrontFrames
        stateLock.unlock()

        if (isBack && backCount <= 3) || (!isBack && frontCount <= 3) ||
            (isBack && backCount % 30 == 0) || (!isBack && frontCount % 30 == 0) {
            VideoDebugLog.log("frame \(isBack ? "back" : "front") #\(isBack ? backCount : frontCount) enabled=\(connection.isEnabled)")
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            VideoDebugLog.log("ERROR sampleBuffer has no image buffer")
            return
        }
        let context = isBack ? backCIContext : frontCIContext
        guard let copied = copyPixelBuffer(pixelBuffer, using: context) else {
            stateLock.lock()
            droppedCopyFailures += 1
            let fails = droppedCopyFailures
            stateLock.unlock()
            if fails <= 5 || fails % 30 == 0 {
                VideoDebugLog.log("ERROR copyPixelBuffer failed #\(fails)")
            }
            return
        }

        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let isPrimary = isBack ? primaryBack : !primaryBack
        if isPrimary {
            active.appendPrimary(copied, time: time)
        } else {
            active.appendSecondary(copied, time: time)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let isBack = output === backVideoOutput
        VideoDebugLog.log("DROPPED \(isBack ? "back" : "front") frame")
    }
}
