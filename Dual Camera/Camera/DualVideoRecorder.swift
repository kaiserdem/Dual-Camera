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
    private var exportConfiguration: VideoExportConfiguration
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

    init(
        outputURL: URL,
        layoutContext: CaptureLayoutContext,
        frameSize: CGSize,
        exportConfiguration: VideoExportConfiguration
    ) {
        self.outputURL = outputURL
        self.layoutContext = layoutContext
        self.frameSize = frameSize
        self.exportConfiguration = exportConfiguration
        super.init()
    }

    func prepare() throws {
        try? FileManager.default.removeItem(at: outputURL)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: exportConfiguration.fileType)

        let width = Int(frameSize.width)
        let height = Int(frameSize.height)
        let videoSettings = Self.makeVideoSettings(
            width: width,
            height: height,
            codec: exportConfiguration.preferredAVCodec,
            writer: writer
        )

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
        let codecName: String = {
            if let type = videoSettings[AVVideoCodecKey] as? AVVideoCodecType {
                return type.rawValue
            }
            if let raw = videoSettings[AVVideoCodecKey] as? String {
                return raw
            }
            return "?"
        }()
        VideoDebugLog.log(
            "prepare OK \(width)x\(height) codec=\(codecName) container=\(exportConfiguration.container.rawValue) → \(outputURL.lastPathComponent)"
        )
    }

    private static func makeVideoSettings(
        width: Int,
        height: Int,
        codec: AVVideoCodecType,
        writer: AVAssetWriter
    ) -> [String: Any] {
        let candidates: [AVVideoCodecType]
        if codec == .hevc {
            candidates = [.hevc, .h264]
        } else {
            candidates = [.h264]
        }

        for candidate in candidates {
            let settings = compressionSettings(width: width, height: height, codec: candidate)
            if writer.canApply(outputSettings: settings, forMediaType: .video) {
                if candidate != codec {
                    VideoDebugLog.log("WARNING codec \(codec.rawValue) unavailable, falling back to \(candidate.rawValue)")
                }
                return settings
            }
        }

        // Last resort — H.264 without profile key.
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate(forPixelCount: width * height, codec: .h264),
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ]
    }

    private static func compressionSettings(
        width: Int,
        height: Int,
        codec: AVVideoCodecType
    ) -> [String: Any] {
        var compression: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate(forPixelCount: width * height, codec: codec),
            AVVideoExpectedSourceFrameRateKey: 30,
            AVVideoMaxKeyFrameIntervalKey: 30
        ]
        if codec == .h264 {
            compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        }

        return [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: compression
        ]
    }

    /// ~bits/pixel/sec at 30fps; HEVC needs less than H.264 for similar quality.
    private static func bitrate(forPixelCount pixelCount: Int, codec: AVVideoCodecType) -> Int {
        let bitsPerPixel = codec == .hevc ? 2.5 : 4.0
        let raw = Int(Double(max(pixelCount, 1)) * bitsPerPixel)
        return min(max(raw, 4_000_000), 16_000_000)
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
        // Dual: wait for secondary. Solo: write as soon as the needed camera is primed.
        let shouldWrite = layoutContext.layout.usesSingleCamera
            ? isSoloSourceReadyLocked()
            : latestSecondary != nil
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
        let shouldKickstart: Bool
        if layoutContext.layout.usesSingleCamera {
            shouldKickstart = isSoloSourceReadyLocked()
        } else {
            // Kick the first frame if primary already arrived; otherwise primary will write.
            shouldKickstart = !isSessionStarted && latestPrimary != nil
        }
        if shouldKickstart, !layoutContext.layout.usesSingleCamera {
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
              !isEncodeBusy else {
            lock.unlock()
            return
        }

        let layout = layoutContext
        let primary: CVPixelBuffer
        let secondary: CVPixelBuffer

        if layout.layout.usesSingleCamera {
            guard let source = soloSourceBufferLocked() else {
                lock.unlock()
                return
            }
            // Pass the same buffer twice; compositor selects by layout + isPrimaryBack.
            primary = source
            secondary = source
        } else {
            guard let p = latestPrimary, let s = latestSecondary else {
                lock.unlock()
                return
            }
            primary = p
            secondary = s
        }

        isEncodeBusy = true
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
            VideoDebugLog.log("FIRST FRAME encoded — UI may have looked 'recording' earlier")
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

    /// Caller must hold `lock`.
    private func isSoloSourceReadyLocked() -> Bool {
        soloSourceBufferLocked() != nil
    }

    /// Caller must hold `lock`. Returns the physical camera buffer for solo layouts.
    private func soloSourceBufferLocked() -> CVPixelBuffer? {
        switch layoutContext.layout {
        case .backOnly:
            return layoutContext.isPrimaryBack ? latestPrimary : latestSecondary
        case .frontOnly:
            return layoutContext.isPrimaryBack ? latestSecondary : latestPrimary
        case .pip, .verticalSplit, .horizontalSplit:
            return nil
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
