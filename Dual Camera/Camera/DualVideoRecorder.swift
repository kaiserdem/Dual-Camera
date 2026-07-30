//
//  DualVideoRecorder.swift
//  Dual Camera
//

import AVFoundation
import UIKit

nonisolated final class DualVideoRecorder: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?
    private var isSessionStarted = false
    private var isRecording = false
    private var didWriteVideoFrame = false
    private var layoutContext: CaptureLayoutContext
    private var outputURL: URL
    private var latestPrimary: CVPixelBuffer?
    private var latestSecondary: CVPixelBuffer?
    private var frameSize: CGSize
    private var lastVideoTime: CMTime = .invalid
    private var frameCount = 0
    private var appendPrimaryCount = 0
    private var appendSecondaryCount = 0
    private var composeFailCount = 0
    private var notReadyCount = 0
    private var appendFailCount = 0
    private var waitingForBothLogged = false
    private var isEncodeBusy = false
    private var isPaused = false
    private var pauseStartSourceTime: CMTime?
    private var totalPausedDuration: CMTime = .zero
    private var lastSourceTime: CMTime = .invalid

    var isPausedRecording: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isPaused
    }

    init(outputURL: URL, layoutContext: CaptureLayoutContext, frameSize: CGSize) {
        self.outputURL = outputURL
        self.layoutContext = layoutContext
        self.frameSize = frameSize
        super.init()
    }

    func prepare() throws {
        try? FileManager.default.removeItem(at: outputURL)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let width = Int(frameSize.width)
        let height = Int(frameSize.height)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 12_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
        )

        guard writer.canAdd(videoInput) else {
            VideoDebugLog.log("ERROR writer.canAdd(videoInput)=false")
            throw CameraError.cannotAddOutput
        }
        writer.add(videoInput)

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 64_000
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        if writer.canAdd(audioInput) {
            writer.add(audioInput)
            self.audioInput = audioInput
        }

        self.assetWriter = writer
        self.videoInput = videoInput
        self.pixelBufferAdaptor = adaptor
        VideoDebugLog.log("prepare OK \(width)x\(height) → \(outputURL.lastPathComponent)")
    }

    func start() {
        lock.lock()
        isRecording = true
        isSessionStarted = false
        didWriteVideoFrame = false
        latestPrimary = nil
        latestSecondary = nil
        lastVideoTime = .invalid
        frameCount = 0
        appendPrimaryCount = 0
        appendSecondaryCount = 0
        composeFailCount = 0
        notReadyCount = 0
        appendFailCount = 0
        waitingForBothLogged = false
        isEncodeBusy = false
        isPaused = false
        pauseStartSourceTime = nil
        totalPausedDuration = .zero
        lastSourceTime = .invalid
        lock.unlock()
        VideoDebugLog.log("recorder.start()")
    }

    func pause() {
        lock.lock()
        guard isRecording, !isPaused else {
            lock.unlock()
            return
        }
        isPaused = true
        pauseStartSourceTime = lastSourceTime.isValid ? lastSourceTime : nil
        lock.unlock()
        VideoDebugLog.log("recorder.pause()")
    }

    func resume() {
        lock.lock()
        guard isRecording, isPaused else {
            lock.unlock()
            return
        }
        isPaused = false
        lock.unlock()
        VideoDebugLog.log("recorder.resume()")
    }

    func appendPrimary(_ buffer: CVPixelBuffer, time: CMTime) {
        lock.lock()
        guard isRecording else {
            lock.unlock()
            return
        }
        updatePauseOffsetIfNeeded(currentTime: time)
        lastSourceTime = time
        guard !isPaused else {
            if pauseStartSourceTime == nil {
                pauseStartSourceTime = time
            }
            lock.unlock()
            return
        }
        appendPrimaryCount += 1
        latestPrimary = buffer
        // Primary drives the output timeline once both cameras are primed.
        let shouldWrite = latestSecondary != nil
        if !shouldWrite, !waitingForBothLogged {
            waitingForBothLogged = true
            VideoDebugLog.log("waiting for secondary camera before first frame")
        }
        lock.unlock()

        if shouldWrite {
            writeFrameIfPossible(time: time)
        }
    }

    func appendSecondary(_ buffer: CVPixelBuffer, time: CMTime) {
        lock.lock()
        guard isRecording else {
            lock.unlock()
            return
        }
        updatePauseOffsetIfNeeded(currentTime: time)
        lastSourceTime = time
        guard !isPaused else {
            if pauseStartSourceTime == nil {
                pauseStartSourceTime = time
            }
            lock.unlock()
            return
        }
        appendSecondaryCount += 1
        latestSecondary = buffer
        // Kick the first frame if primary already arrived; otherwise primary will write.
        let shouldKickstart = !isSessionStarted && latestPrimary != nil
        if shouldKickstart {
            VideoDebugLog.log("secondary primed — starting dual frames")
        }
        lock.unlock()

        if shouldKickstart {
            writeFrameIfPossible(time: time)
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        guard isRecording,
              !isPaused,
              isSessionStarted,
              let writer = assetWriter,
              writer.status == .writing,
              let audioInput,
              audioInput.isReadyForMoreMediaData else {
            lock.unlock()
            return
        }

        let totalPaused = totalPausedDuration
        lock.unlock()

        let sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let adjustedTime = CMTimeSubtract(sourceTime, totalPaused)
        var timingCount: CMItemCount = 0
        CMSampleBufferGetOutputSampleTimingInfoArray(sampleBuffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &timingCount)
        var timings = Array(repeating: CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .invalid, decodeTimeStamp: .invalid), count: timingCount)
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: timingCount, arrayToFill: &timings, entriesNeededOut: &timingCount)
        for i in 0..<timings.count {
            timings[i].presentationTimeStamp = CMTimeSubtract(timings[i].presentationTimeStamp, totalPaused)
            if timings[i].decodeTimeStamp.isValid {
                timings[i].decodeTimeStamp = CMTimeSubtract(timings[i].decodeTimeStamp, totalPaused)
            }
        }
        var adjustedBuffer: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: timings.count, sampleTimingArray: &timings, sampleBufferOut: &adjustedBuffer)
        if let adjustedBuffer {
            audioInput.append(adjustedBuffer)
        } else {
            VideoDebugLog.log("ERROR audio retiming failed at \(CMTimeGetSeconds(adjustedTime))")
        }
    }

    private func updatePauseOffsetIfNeeded(currentTime: CMTime) {
        guard !isPaused, let pauseStart = pauseStartSourceTime else { return }
        let delta = CMTimeSubtract(currentTime, pauseStart)
        if delta.isValid, CMTimeCompare(delta, .zero) > 0 {
            totalPausedDuration = CMTimeAdd(totalPausedDuration, delta)
        }
        pauseStartSourceTime = nil
        VideoDebugLog.log("pause offset now \(CMTimeGetSeconds(totalPausedDuration))s")
    }

    func stop(completion: @escaping (URL?) -> Void) {
        lock.lock()
        isRecording = false
        let writer = assetWriter
        let started = isSessionStarted
        let wrote = didWriteVideoFrame
        let count = frameCount
        let primaryCount = appendPrimaryCount
        let secondaryCount = appendSecondaryCount
        let composeFails = composeFailCount
        let notReady = notReadyCount
        let appendFails = appendFailCount
        let writerStatus = assetWriter?.status.rawValue ?? -1
        let writerError = assetWriter?.error?.localizedDescription ?? "nil"
        let videoInput = self.videoInput
        let audioInput = self.audioInput
        lock.unlock()

        VideoDebugLog.log(
            """
            recorder.stop stats: started=\(started) wrote=\(wrote) frames=\(count) \
            primary=\(primaryCount) secondary=\(secondaryCount) composeFail=\(composeFails) \
            notReady=\(notReady) appendFail=\(appendFails) writerStatus=\(writerStatus) error=\(writerError)
            """
        )

        guard let writer else {
            VideoDebugLog.log("ERROR stop: writer is nil")
            completion(nil)
            return
        }

        guard started, writer.status == .writing, wrote, count > 0 else {
            VideoDebugLog.log("ERROR stop: aborting empty recording")
            if writer.status == .writing {
                writer.cancelWriting()
            }
            try? FileManager.default.removeItem(at: outputURL)
            reset()
            completion(nil)
            return
        }

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        let finishedURL = outputURL
        writer.finishWriting {
            let success = writer.status == .completed
            VideoDebugLog.log(
                "finishWriting status=\(writer.status.rawValue) error=\(writer.error?.localizedDescription ?? "nil") success=\(success)"
            )
            if success {
                completion(finishedURL)
            } else {
                try? FileManager.default.removeItem(at: writer.outputURL)
                completion(nil)
            }
        }
        reset()
    }

    private func writeFrameIfPossible(time: CMTime) {
        // Snapshot under lock, compose outside — holding the lock during compose
        // blocked the other camera's callbacks and caused late-frame drops.
        lock.lock()
        guard isRecording,
              !isPaused,
              !isEncodeBusy,
              let primary = latestPrimary,
              let secondary = latestSecondary else {
            lock.unlock()
            return
        }
        isEncodeBusy = true
        let layout = layoutContext
        let size = frameSize
        let pausedDuration = totalPausedDuration
        lock.unlock()

        let composed = DualFrameCompositor.compose(
            primary: primary,
            secondary: secondary,
            context: layout,
            outputSize: size
        )

        lock.lock()
        defer {
            isEncodeBusy = false
            lock.unlock()
        }

        guard let composed else {
            composeFailCount += 1
            if composeFailCount <= 5 || composeFailCount % 30 == 0 {
                VideoDebugLog.log("ERROR compose failed #\(composeFailCount)")
            }
            return
        }

        guard isRecording, !isPaused, let writer = assetWriter, let videoInput, let adaptor = pixelBufferAdaptor else {
            return
        }

        if !isSessionStarted {
            let ok = writer.startWriting()
            VideoDebugLog.log("startWriting ok=\(ok) status=\(writer.status.rawValue) error=\(writer.error?.localizedDescription ?? "nil")")
            guard ok, writer.status == .writing else { return }
            let startTime = CMTimeSubtract(time, pausedDuration)
            writer.startSession(atSourceTime: startTime)
            isSessionStarted = true
            VideoDebugLog.log("startSession at \(CMTimeGetSeconds(startTime)) (dual cameras primed)")
        }

        guard writer.status == .writing else {
            VideoDebugLog.log("ERROR writer status=\(writer.status.rawValue) error=\(writer.error?.localizedDescription ?? "nil")")
            return
        }

        guard videoInput.isReadyForMoreMediaData else {
            notReadyCount += 1
            if notReadyCount <= 5 || notReadyCount % 30 == 0 {
                VideoDebugLog.log("videoInput not ready #\(notReadyCount)")
            }
            return
        }

        let presentationTime = CMTimeSubtract(time, totalPausedDuration)
        if lastVideoTime.isValid, CMTimeCompare(presentationTime, lastVideoTime) <= 0 {
            return
        }

        if adaptor.append(composed, withPresentationTime: presentationTime) {
            lastVideoTime = presentationTime
            didWriteVideoFrame = true
            frameCount += 1
            if frameCount <= 3 || frameCount % 30 == 0 {
                VideoDebugLog.log("appended frame #\(frameCount)")
            }
        } else {
            appendFailCount += 1
            if appendFailCount <= 5 || appendFailCount % 30 == 0 {
                VideoDebugLog.log("ERROR adaptor.append failed #\(appendFailCount) writerError=\(writer.error?.localizedDescription ?? "nil")")
            }
        }
    }

    private func reset() {
        lock.lock()
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        latestPrimary = nil
        latestSecondary = nil
        isSessionStarted = false
        didWriteVideoFrame = false
        frameCount = 0
        isPaused = false
        pauseStartSourceTime = nil
        totalPausedDuration = .zero
        lastVideoTime = .invalid
        lastSourceTime = .invalid
        waitingForBothLogged = false
        isEncodeBusy = false
        lock.unlock()
    }
}
