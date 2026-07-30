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

    var captureMode: CaptureMode = .photo
    var activeOverlay: ActiveOverlay = .none
    var selectedZoom: ZoomLevel = .one
    var isGridEnabled = false
    var isLevelerEnabled = false {
        didSet { motionManager.isActive = isLevelerEnabled }
    }
    var isFlashEnabled = false {
        didSet {
            cameraManager.flashMode = isFlashEnabled ? .on : .off
            cameraManager.setTorchEnabled(isFlashEnabled && captureMode == .video)
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

    /// Layout / PiP / split / ratio edits are locked for the duration of a take.
    var isLayoutLocked: Bool { isRecording }

    var selectedRatio: AspectRatio {
        get { settings.selectedRatio }
        set {
            guard !isLayoutLocked else { return }
            settings.selectedRatio = newValue
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
    var isRecording: Bool { cameraManager.isRecording }
    var isRecordingPaused: Bool { cameraManager.isRecordingPaused }
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
        cameraManager.prepare()
    }

    func onDisappear() {
        stopRecordingTimer()
        galleryThumbnailResetTask?.cancel()
        galleryThumbnailResetTask = nil
        cameraManager.stopSession()
        motionManager.isActive = false
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
        selectedZoom = level
        cameraManager.setZoom(level)
    }

    func handleShutter() {
        let layout = makeCaptureLayoutContext()
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
        guard isRecording else { return }
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
