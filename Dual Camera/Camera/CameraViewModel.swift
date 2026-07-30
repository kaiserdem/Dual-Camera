//
//  CameraViewModel.swift
//  Dual Camera
//

import AVFoundation
import CoreGraphics
import Foundation
import Observation
import UIKit

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
    var pipPosition: CGPoint?
    var showSettings = false

    var selectedRatio: AspectRatio {
        get { settings.selectedRatio }
        set { settings.selectedRatio = newValue }
    }

    var selectedLayout: CameraLayout {
        get { settings.selectedLayout }
        set { settings.selectedLayout = newValue }
    }

    var pipShape: PiPShape {
        get { settings.pipShape }
        set { settings.pipShape = newValue }
    }

    var isBorderEnabled: Bool {
        get { settings.isBorderEnabled }
        set { settings.isBorderEnabled = newValue }
    }

    var borderWidth: CGFloat {
        get { settings.borderWidth }
        set { settings.borderWidth = min(max(newValue, 1), 8) }
    }

    var borderStyle: BorderStyle {
        get { settings.borderStyle }
        set { settings.borderStyle = newValue }
    }

    var isMultiCamAvailable: Bool { cameraManager.isMultiCamAvailable }
    var isSessionRunning: Bool { cameraManager.isSessionRunning }
    var isRecording: Bool { cameraManager.isRecording }
    var lastCapturedImage: UIImage? { cameraManager.lastCapturedImage }
    var errorMessage: String? {
        get { cameraManager.errorMessage }
        set { cameraManager.errorMessage = newValue }
    }
    var primaryPort: AVCaptureInput.Port? { cameraManager.primaryVideoPort }
    var secondaryPort: AVCaptureInput.Port? { cameraManager.secondaryVideoPort }
    var session: AVCaptureMultiCamSession { cameraManager.session }
    var levelerRoll: Double { motionManager.roll }

    func onAppear() {
        cameraManager.prepare()
    }

    func onDisappear() {
        cameraManager.stopSession()
        motionManager.isActive = false
    }

    func toggleOverlay(_ overlay: ActiveOverlay) {
        activeOverlay = activeOverlay == overlay ? .none : overlay
    }

    func dismissOverlay() {
        activeOverlay = .none
    }

    func swapCameras() {
        cameraManager.swapCameras()
    }

    func selectZoom(_ level: ZoomLevel) {
        selectedZoom = level
        cameraManager.setZoom(level)
    }

    func handleShutter() {
        switch captureMode {
        case .photo:
            cameraManager.takePhoto()
        case .video:
            cameraManager.toggleRecording()
        }
    }

    func increaseBorderWidth() {
        borderWidth += 1
    }

    func decreaseBorderWidth() {
        borderWidth -= 1
    }
}
