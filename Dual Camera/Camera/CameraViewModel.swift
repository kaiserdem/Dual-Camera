//
//  CameraViewModel.swift
//  Dual Camera
//

import AVFoundation
import CoreGraphics
import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class CameraViewModel {
    let cameraManager = CameraManager()
    let settings = AppSettings()
    let motionManager = MotionManager()

    var captureMode: CaptureMode = .photo {
        didSet {
            guard oldValue != captureMode else { return }
            syncFlashHardware()
        }
    }
    var activeOverlay: ActiveOverlay = .none
    var selectedZoom: ZoomLevel = .one
    var isGridEnabled = false
    var isLevelerEnabled = false {
        didSet { motionManager.isActive = isLevelerEnabled }
    }
    /// Photo: Off → On → Auto. Video torch: Off ↔ On (Auto is ignored for torch).
    var flashMode: FlashModeOption {
        get { settings.flashMode }
        set {
            guard settings.flashMode != newValue else { return }
            settings.flashMode = newValue
            syncFlashHardware()
        }
    }
    /// Frozen while recording so export matches the layout captured at start.
    private var storedPipPosition: CGPoint?
    var pipPosition: CGPoint? {
        get { storedPipPosition }
        set {
            guard !isRecording else { return }
            storedPipPosition = newValue
        }
    }
    var viewfinderSize: CGSize = .zero
    var showSettings = false
    var showTeleprompterEditor = false
    /// While Settings is open, layout chrome reads this snapshot instead of live `settings`
    /// so toggles do not rebuild the camera preview under the navigation stack.
    private var frozenAppearance: (floatingChrome: Bool, fullBleedBackground: Bool)?
    /// True while applying appearance after Settings or waiting for session start.
    var isCameraWarmingUp = false
    private var appearanceApplyTask: Task<Void, Never>?
    /// Idle top chrome tucked away — only a restore pill remains.
    var isTopBarCollapsed = false

    var effectiveFloatingChrome: Bool {
        frozenAppearance?.floatingChrome ?? settings.isFloatingCameraChromeEnabled
    }

    var effectiveFullBleedBackground: Bool {
        frozenAppearance?.fullBleedBackground ?? settings.isFullBleedCameraBackgroundEnabled
    }

    /// Show spinner when session is down or appearance is mid-apply.
    var showsCameraLoadingIndicator: Bool {
        isCameraWarmingUp || !isSessionRunning
    }

    func onSettingsOpened() {
        appearanceApplyTask?.cancel()
        appearanceApplyTask = nil
        frozenAppearance = (
            floatingChrome: settings.isFloatingCameraChromeEnabled,
            fullBleedBackground: settings.isFullBleedCameraBackgroundEnabled
        )
        VideoDebugLog.log(
            "settings OPEN freeze floating=\(frozenAppearance!.floatingChrome) " +
            "fullBleed=\(frozenAppearance!.fullBleedBackground) " +
            "sessionRunning=\(isSessionRunning) configured=\(cameraManager.isConfigured)"
        )
    }

    func onSettingsClosed() {
        let frozen = frozenAppearance
        let nextFloating = settings.isFloatingCameraChromeEnabled
        let nextFullBleed = settings.isFullBleedCameraBackgroundEnabled
        let appearanceChanged =
            frozen.map { $0.floatingChrome != nextFloating || $0.fullBleedBackground != nextFullBleed } ?? true

        VideoDebugLog.log(
            "settings CLOSE requested appearanceChanged=\(appearanceChanged) " +
            "frozenFloating=\(frozen?.floatingChrome.description ?? "nil") → \(nextFloating) " +
            "sessionRunning=\(isSessionRunning)"
        )

        appearanceApplyTask?.cancel()
        isCameraWarmingUp = true

        // Let the navigation pop finish before swapping chrome / touching the session.
        appearanceApplyTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            VideoDebugLog.log(
                "settings APPLY appearance floating=\(nextFloating) fullBleed=\(nextFullBleed) " +
                "session.isRunning(hardware)=\(cameraManager.session.isRunning)"
            )
            frozenAppearance = nil

            cameraManager.prepare()
            syncFlashHardware()
            motionManager.isActive = isLevelerEnabled

            // Wait briefly for session flag; spinner clears when running.
            for _ in 0..<40 {
                if Task.isCancelled { return }
                if isSessionRunning {
                    break
                }
                try? await Task.sleep(for: .milliseconds(50))
            }

            VideoDebugLog.log(
                "settings APPLY done sessionRunning=\(isSessionRunning) " +
                "hardwareRunning=\(cameraManager.session.isRunning) warmingUp→false"
            )
            isCameraWarmingUp = false
            appearanceApplyTask = nil
        }
    }

    /// Layout / PiP / split / ratio edits are locked for the duration of a take.
    var isLayoutLocked: Bool { isRecording }

    var selectedRatio: AspectRatio {
        get { settings.selectedRatio }
        set {
            guard !isLayoutLocked else { return }
            let previous = settings.selectedRatio
            settings.selectedRatio = newValue
            // Keep one default PiP placement across ratio modes (absolute coords don't transfer).
            if previous != newValue {
                pipPosition = nil
            }
        }
    }

    var selectedLayout: CameraLayout {
        get { settings.selectedLayout }
        set {
            guard !isLayoutLocked else { return }
            settings.selectedLayout = newValue
        }
    }

    var pipShape: PiPShape {
        get { settings.pipShape }
        set {
            guard !isLayoutLocked else { return }
            settings.pipShape = newValue
        }
    }

    var isPiPRounded: Bool {
        get { settings.isPiPRounded }
        set {
            guard !isLayoutLocked else { return }
            settings.isPiPRounded = newValue
        }
    }

    var pipScale: CGFloat {
        get { settings.pipScale }
        set {
            guard !isLayoutLocked else { return }
            settings.pipScale = AppSettings.clampedPipScale(Double(newValue))
        }
    }

    var isBorderEnabled: Bool {
        get { settings.isBorderEnabled }
        set {
            guard !isLayoutLocked else { return }
            settings.isBorderEnabled = newValue
        }
    }

    var borderWidth: CGFloat {
        get { settings.borderWidth }
        set {
            guard !isLayoutLocked else { return }
            settings.borderWidth = min(max(newValue, 1), 8)
        }
    }

    var borderStyle: BorderStyle {
        get { settings.borderStyle }
        set {
            guard !isLayoutLocked else { return }
            settings.borderStyle = newValue
        }
    }

    var borderColor: Color {
        get { settings.borderColor }
        set {
            guard !isLayoutLocked else { return }
            settings.borderColor = newValue
        }
    }

    var borderLineStyle: BorderLineStyle {
        get { settings.borderLineStyle }
        set {
            guard !isLayoutLocked else { return }
            settings.borderLineStyle = newValue
        }
    }

    var verticalSplitRatio: CGFloat {
        get { settings.verticalSplitRatio }
        set {
            guard !isLayoutLocked else { return }
            settings.verticalSplitRatio = AppSettings.clampedSplitRatio(Double(newValue))
        }
    }

    var horizontalSplitRatio: CGFloat {
        get { settings.horizontalSplitRatio }
        set {
            guard !isLayoutLocked else { return }
            settings.horizontalSplitRatio = AppSettings.clampedSplitRatio(Double(newValue))
        }
    }

    var isMultiCamAvailable: Bool { cameraManager.isMultiCamAvailable }
    var isSessionRunning: Bool { cameraManager.isSessionRunning }
    /// Zoom chips — only after the capture session is live.
    var isZoomControlEnabled: Bool { isSessionRunning }
    var isRecording: Bool { cameraManager.isRecording }
    var isRecordingPaused: Bool { cameraManager.isRecordingPaused }
    /// Flash (photo) or torch (video) chip — only when the active back camera supports it.
    var isFlashControlAvailable: Bool {
        captureMode == .video ? cameraManager.isTorchAvailable : cameraManager.isFlashAvailable
    }
    var recordingElapsed: TimeInterval = 0
    var lastCapturedImage: UIImage? { cameraManager.lastCapturedImage }
    var photoCaptureCount: Int { cameraManager.photoCaptureCount }
    /// Temporary gallery button preview; cleared a few seconds after capture.
    var galleryThumbnailImage: UIImage?
    /// 0...1 white flash over the viewfinder after shutter.
    var shutterFlashOpacity: Double = 0
    /// Gallery thumbnail pulse scale.
    var galleryPulseScale: CGFloat = 1
    var errorMessage: String? {
        get { cameraManager.errorMessage }
        set { cameraManager.errorMessage = newValue }
    }
    var primaryPort: AVCaptureInput.Port? { cameraManager.primaryVideoPort }
    var secondaryPort: AVCaptureInput.Port? { cameraManager.secondaryVideoPort }
    var session: AVCaptureMultiCamSession { cameraManager.session }
    var levelerRoll: Double { motionManager.roll }

    var formattedRecordingTime: String {
        let totalSeconds = max(0, Int(recordingElapsed.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var recordingTimer: Timer?
    private var recordingAccumulated: TimeInterval = 0
    private var recordingSegmentStartedAt: Date?
    private var galleryThumbnailResetTask: Task<Void, Never>?

    func onAppear() {
        VideoDebugLog.log(
            "CameraView.onAppear sessionRunning=\(isSessionRunning) " +
            "configured=\(cameraManager.isConfigured) showSettings=\(showSettings)"
        )
        if !showSettings {
            isCameraWarmingUp = !isSessionRunning
        }
        cameraManager.prepare()
        syncFlashHardware()
        motionManager.isActive = isLevelerEnabled
        if isSessionRunning {
            isCameraWarmingUp = false
        }
    }

    /// Covered by another screen in the same stack (e.g. Settings) — keep the capture session alive.
    func onDisappear() {
        VideoDebugLog.log(
            "CameraView.onDisappear showSettings=\(showSettings) sessionRunning=\(isSessionRunning)"
        )
        stopRecordingIfNeeded()
        stopRecordingTimer()
        galleryThumbnailResetTask?.cancel()
        galleryThumbnailResetTask = nil
        cameraManager.setTorchEnabled(false)
        motionManager.isActive = false
    }

    /// App background / multitasking — finalize recording and release the camera.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            VideoDebugLog.log("scenePhase.background — stop recording and session")
            stopRecordingIfNeeded()
            stopRecordingTimer()
            cameraManager.setTorchEnabled(false)
            cameraManager.stopSession()
            motionManager.isActive = false
        case .active:
            cameraManager.prepare()
            syncFlashHardware()
            motionManager.isActive = isLevelerEnabled
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    private func stopRecordingIfNeeded() {
        guard isRecording else { return }
        VideoDebugLog.log("stopRecordingIfNeeded — finalizing take")
        cameraManager.stopRecording()
        stopRecordingTimer()
    }

    /// Photo: Off → On → Auto. Video: Off ↔ On (continuous torch).
    func cycleFlashMode() {
        guard isFlashControlAvailable else { return }
        switch captureMode {
        case .photo:
            switch flashMode {
            case .off: flashMode = .on
            case .on: flashMode = .auto
            case .auto: flashMode = .off
            }
        case .video:
            flashMode = flashMode == .off ? .on : .off
        }
    }

    /// Photo uses still flash at capture; video uses continuous torch — only while Video + On.
    func syncFlashHardware() {
        if !isFlashControlAvailable {
            cameraManager.flashMode = .off
            cameraManager.setTorchEnabled(false)
            if flashMode != .off {
                flashMode = .off
            }
            return
        }

        let modeForCapture: FlashModeOption
        if captureMode == .video, flashMode == .auto {
            // Torch has no Auto — treat leftover Auto from Photo as Off until user cycles.
            modeForCapture = .off
        } else {
            modeForCapture = flashMode
        }
        cameraManager.flashMode = modeForCapture
        cameraManager.setTorchEnabled(captureMode == .video && modeForCapture == .on)
    }

    func toggleOverlay(_ overlay: ActiveOverlay) {
        if isLayoutLocked, overlay == .layout || overlay == .ratio {
            return
        }
        activeOverlay = activeOverlay == overlay ? .none : overlay
    }

    func dismissOverlay() {
        activeOverlay = .none
    }

    func swapCameras() {
        guard !isLayoutLocked else { return }
        cameraManager.swapCameras()
    }

    func selectZoom(_ level: ZoomLevel) {
        guard isZoomControlEnabled else { return }
        selectedZoom = level
        cameraManager.setZoom(level)
    }

    func handleShutter() {
        let layout = makeCaptureLayoutContext()
        VideoDebugLog.log(
            "ViewModel.handleShutter mode=\(captureMode.rawValue) isRecording=\(isRecording) " +
            "viewfinder=\(Int(layout.viewfinderSize.width))x\(Int(layout.viewfinderSize.height))"
        )
        switch captureMode {
        case .photo:
            triggerShutterFlash()
            cameraManager.takePhoto(layout: layout)
        case .video:
            if isRecording {
                cameraManager.toggleRecording(layout: layout, export: settings.videoExportConfiguration)
            } else {
                dismissOverlay()
                cameraManager.toggleRecording(layout: layout, export: settings.videoExportConfiguration)
            }
        }
    }

    func triggerShutterFlash() {
        shutterFlashOpacity = 0.9
        withAnimation(.easeOut(duration: 0.18)) {
            shutterFlashOpacity = 0
        }
    }

    func triggerGalleryCapturePulse() {
        galleryThumbnailResetTask?.cancel()
        galleryThumbnailImage = lastCapturedImage

        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            galleryPulseScale = 1.32
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.52)) {
            galleryPulseScale = 1
        }

        galleryThumbnailResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                galleryThumbnailImage = nil
            }
        }
    }

    func toggleRecordingPause() {
        guard isRecording else {
            VideoDebugLog.log("ViewModel.toggleRecordingPause IGNORED — not recording")
            return
        }
        VideoDebugLog.log("ViewModel.toggleRecordingPause -> \(isRecordingPaused ? "resume" : "pause")")
        if isRecordingPaused {
            cameraManager.resumeRecording()
            resumeRecordingTimer()
        } else {
            cameraManager.pauseRecording()
            pauseRecordingTimer()
        }
    }

    func syncRecordingTimer(isRecording: Bool) {
        if isRecording {
            startRecordingTimer()
        } else {
            stopRecordingTimer()
        }
    }

    private func startRecordingTimer() {
        stopRecordingTimer()
        recordingAccumulated = 0
        recordingElapsed = 0
        recordingSegmentStartedAt = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tickRecordingTimer()
            }
        }
    }

    private func pauseRecordingTimer() {
        if let started = recordingSegmentStartedAt {
            recordingAccumulated += Date().timeIntervalSince(started)
            recordingSegmentStartedAt = nil
        }
        recordingElapsed = recordingAccumulated
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func resumeRecordingTimer() {
        recordingSegmentStartedAt = Date()
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tickRecordingTimer()
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingSegmentStartedAt = nil
        recordingAccumulated = 0
        recordingElapsed = 0
    }

    private func tickRecordingTimer() {
        guard let started = recordingSegmentStartedAt else {
            recordingElapsed = recordingAccumulated
            return
        }
        recordingElapsed = recordingAccumulated + Date().timeIntervalSince(started)
    }

    func makeCaptureLayoutContext() -> CaptureLayoutContext {
        let size = viewfinderSize == .zero ? CGSize(width: 390, height: 720) : viewfinderSize
        return CaptureLayoutContext(
            layout: selectedLayout,
            pipShape: pipShape,
            isPiPRounded: isPiPRounded,
            pipScale: pipScale,
            isBorderEnabled: isBorderEnabled,
            borderWidth: borderWidth,
            borderColor: UIColor(borderColor),
            borderLineStyle: borderLineStyle,
            verticalSplitRatio: verticalSplitRatio,
            horizontalSplitRatio: horizontalSplitRatio,
            aspectRatio: selectedRatio,
            viewfinderSize: size,
            pipCenter: pipPosition ?? CaptureLayoutContext.defaultPiPCenter(
                in: size,
                shape: pipShape,
                scale: pipScale
            )
        )
    }

    func openGallery() {
        guard let url = URL(string: "photos-redirect://") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Teleprompter

    /// Idle: open editor. Recording: toggle overlay + scroll without opening settings.
    func handleTeleprompterButtonTap() {
        if isRecording {
            toggleTeleprompterOverlay()
        } else {
            showTeleprompterEditor = true
        }
    }

    /// Show or hide the teleprompter overlay (used while recording).
    func toggleTeleprompterOverlay() {
        if settings.isTeleprompterActive {
            deactivateTeleprompter()
        } else {
            activateTeleprompter(play: true)
        }
    }

    /// Activate overlay; optionally begin scroll (after configured delay inside the view).
    func activateTeleprompter(play: Bool) {
        let hasText = !settings.teleprompterText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        guard hasText else { return }
        settings.isTeleprompterActive = true
        settings.isTeleprompterScrolling = play
    }

    func deactivateTeleprompter() {
        settings.isTeleprompterActive = false
        settings.isTeleprompterScrolling = false
    }

    /// Auto-start overlay when recording begins (if enabled and script exists).
    func handleTeleprompterRecordingStarted() {
        guard settings.teleprompterAutoStartWithRecording else { return }
        activateTeleprompter(play: true)
    }

    /// Keep overlay visible; pause scroll when recording ends.
    func handleTeleprompterRecordingStopped() {
        settings.isTeleprompterScrolling = false
    }

    func increaseBorderWidth() {
        borderWidth += 1
    }

    func decreaseBorderWidth() {
        borderWidth -= 1
    }

    func applyBorderPreset(_ style: BorderStyle) {
        guard !isLayoutLocked else { return }
        settings.applyBorderPreset(style)
    }
}
