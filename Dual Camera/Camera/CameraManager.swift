//
//  CameraManager.swift
//  Dual Camera
//

import AVFoundation
import ImageIO
import Photos
import UIKit
import Observation

@Observable
final class CameraManager: NSObject {
    let session = AVCaptureMultiCamSession()

    private(set) var backVideoPort: AVCaptureInput.Port?
    private(set) var frontVideoPort: AVCaptureInput.Port?
    private(set) var isSessionRunning = false
    private(set) var isConfigured = false
    private(set) var isRecording = false
    private(set) var isRecordingPaused = false
    private(set) var lastCapturedImage: UIImage?
    /// Bumps each time a photo or video is ready — drives gallery capture feedback.
    private(set) var photoCaptureCount = 0
    private(set) var isMultiCamAvailable = MultiCamSupport.isSupported
    private(set) var isPrimaryBack = true
    private(set) var hasUltraWide = false
    /// True when back input is DualWide/Triple — 0.5× via zoom ramp, not input swap.
    private(set) var usesVirtualBackZoom = false
    /// Back camera still-flash support (front typically has none).
    private(set) var isFlashAvailable = false
    /// Back camera continuous torch support.
    private(set) var isTorchAvailable = false

    var errorMessage: String?
    var flashMode: FlashModeOption = .off

    /// Currently connected back camera (wide, ultra-wide, or virtual Dual/Triple).
    private var activeBackDevice: AVCaptureDevice? {
        backCameraInput?.device ?? backDevice
    }

    private let sessionQueue = DispatchQueue(label: "com.dualcamera.session")
    private let backPhotoOutput = AVCapturePhotoOutput()
    private let frontPhotoOutput = AVCapturePhotoOutput()
    private let videoEngine = DualVideoEngine()

    private var backCameraInput: AVCaptureDeviceInput?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var microphoneInput: AVCaptureDeviceInput?
    /// Preferred non-virtual wide (fallback zoom / switch target).
    private var backDevice: AVCaptureDevice?
    private var ultraWideDevice: AVCaptureDevice?
    /// Last zoom level requested from UI; applied after configure and on each setZoom.
    private var pendingZoomLevel: ZoomLevel = .one

    private var dualPhotoDelegates: [PhotoCaptureDelegate] = []
    private var activeLayoutContext: CaptureLayoutContext?
    private var pendingPrimaryImage: UIImage?
    private var pendingSecondaryImage: UIImage?
    private let photoLock = NSLock()

    var primaryVideoPort: AVCaptureInput.Port? {
        isPrimaryBack ? backVideoPort : frontVideoPort
    }

    var secondaryVideoPort: AVCaptureInput.Port? {
        isPrimaryBack ? frontVideoPort : backVideoPort
    }

    override init() {
        super.init()
        videoEngine.onRecordingFinished = { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                VideoDebugLog.log("CameraManager.onRecordingFinished received")
                self.isRecording = false
                switch result {
                case .success(let url):
                    self.isRecordingPaused = false
                    VideoDebugLog.log("CameraManager UI flag isRecording=false (save begins)")
                    self.saveVideoToPhotos(url)
                case .failure(let error):
                    self.isRecordingPaused = false
                    VideoDebugLog.log("CameraManager recording FAILED \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func prepare() {
        guard isMultiCamAvailable else {
            errorMessage = MultiCamSupport.unsupportedMessage
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestMicrophoneThenConfigure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.requestMicrophoneThenConfigure()
                    } else {
                        self?.errorMessage = "Camera access is required to use Dual Camera."
                    }
                }
            }
        default:
            errorMessage = "Camera access is required to use Dual Camera."
        }
    }

    private func requestMicrophoneThenConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized, .denied, .restricted:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                Task { @MainActor in
                    self?.configureAndStart()
                }
            }
        @unknown default:
            configureAndStart()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.isRecording {
                self.videoEngine.stopRecording()
            }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            Task { @MainActor in
                self.isSessionRunning = false
                self.isRecording = false
            }
        }
    }

    func swapCameras() {
        guard !isRecording else { return }
        isPrimaryBack.toggle()
        videoEngine.updatePrimaryBack(isPrimaryBack)
    }

    func setZoom(_ level: ZoomLevel) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.pendingZoomLevel = level
            self.applyPendingZoom()
        }
    }

    private func applyPendingZoom(animated: Bool = true) {
        let level = pendingZoomLevel

        // Virtual DualWide/Triple: one input, smooth lens switch via zoom factor.
        if usesVirtualBackZoom, let device = activeBackDevice {
            let factor = videoZoomFactor(for: level, on: device)
            VideoDebugLog.log(
                "zoom virtual \(level.title) → factor=\(factor) " +
                "min=\(device.minAvailableVideoZoomFactor) " +
                "switchOver=\(device.virtualDeviceSwitchOverVideoZoomFactors)"
            )
            applyZoom(on: device, factor: factor, animated: animated)
            return
        }

        // Fallback: Ultra Wide is a separate device — must swap inputs (brief black frame).
        if level == .half, let ultraWide = ultraWideDevice, hasUltraWide {
            switchBackCamera(to: ultraWide, preferredZoom: 1.0)
            return
        }

        guard let device = backDevice else { return }
        if level == .half && !hasUltraWide {
            applyZoom(on: device, factor: 1.0, animated: animated)
            return
        }

        if backCameraInput?.device !== device {
            switchBackCamera(to: device, preferredZoom: level.factor)
        } else {
            applyZoom(on: device, factor: max(level.factor, 1.0), animated: animated)
        }
    }

    func setTorchEnabled(_ enabled: Bool) {
        sessionQueue.async { [weak self] in
            guard let self,
                  let device = self.activeBackDevice,
                  device.hasTorch,
                  device.isTorchModeSupported(enabled ? .on : .off) else { return }
            do {
                try device.lockForConfiguration()
                if enabled, device.isTorchAvailable {
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                Task { @MainActor in
                    self.errorMessage = "Unable to change torch: \(error.localizedDescription)"
                }
            }
        }
    }

    private func refreshLightCapabilities() {
        let device = activeBackDevice
        let flash = (device?.hasFlash ?? false) && (device?.isFlashAvailable ?? false)
        let torch = (device?.hasTorch ?? false) && (device?.isTorchAvailable ?? false)
        Task { @MainActor in
            self.isFlashAvailable = flash
            self.isTorchAvailable = torch
        }
    }

    func takePhoto(layout: CaptureLayoutContext) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isRecording else {
                Task { @MainActor in
                    self.errorMessage = "Stop video recording before taking a photo."
                }
                return
            }

            guard self.backPhotoOutput.connection(with: .video)?.isEnabled == true,
                  self.frontPhotoOutput.connection(with: .video)?.isEnabled == true else {
                Task { @MainActor in
                    self.errorMessage = "Photo capture is not available."
                }
                return
            }

            self.activeLayoutContext = layout
            self.pendingPrimaryImage = nil
            self.pendingSecondaryImage = nil
            self.dualPhotoDelegates.removeAll()

            let backSettings = self.makePhotoSettings(for: self.backPhotoOutput)
            let frontSettings = self.makePhotoSettings(for: self.frontPhotoOutput)

            let backDelegate = PhotoCaptureDelegate { [weak self] image in
                self?.handleDualPhoto(image: image, isBack: true)
            }
            let frontDelegate = PhotoCaptureDelegate { [weak self] image in
                self?.handleDualPhoto(image: image, isBack: false)
            }
            self.dualPhotoDelegates = [backDelegate, frontDelegate]

            self.backPhotoOutput.capturePhoto(with: backSettings, delegate: backDelegate)
            self.frontPhotoOutput.capturePhoto(with: frontSettings, delegate: frontDelegate)
        }
    }

    func toggleRecording(layout: CaptureLayoutContext, export: VideoExportConfiguration) {
        VideoDebugLog.log("CameraManager.toggleRecording isRecording=\(isRecording)")
        if isRecording {
            stopRecording()
        } else {
            startRecording(layout: layout, export: export)
        }
    }

    func startRecording(layout: CaptureLayoutContext, export: VideoExportConfiguration) {
        VideoDebugLog.log("CameraManager.startRecording isConfigured=\(videoEngine.isConfigured)")
        guard !isRecording else {
            VideoDebugLog.log("CameraManager.startRecording ignored — already recording")
            return
        }
        guard videoEngine.isConfigured else {
            VideoDebugLog.log("ERROR video engine not configured")
            errorMessage = "Video engine is not ready."
            return
        }
        isRecording = true
        isRecordingPaused = false
        VideoDebugLog.log("CameraManager UI flag isRecording=true (engine start still queued)")
        videoEngine.updatePrimaryBack(isPrimaryBack)

        sessionQueue.async { [weak self] in
            guard let self else { return }
            VideoDebugLog.log("CameraManager sessionQueue: begin engine.startRecording")
            do {
                try self.videoEngine.startRecording(layout: layout, export: export)
                VideoDebugLog.log("CameraManager.startRecording engine started")
            } catch {
                VideoDebugLog.log("ERROR CameraManager.startRecording \(error)")
                Task { @MainActor in
                    self.isRecording = false
                    self.isRecordingPaused = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func pauseRecording() {
        guard isRecording, !isRecordingPaused else {
            VideoDebugLog.log(
                "CameraManager.pauseRecording IGNORED isRecording=\(isRecording) isPaused=\(isRecordingPaused)"
            )
            return
        }
        isRecordingPaused = true
        VideoDebugLog.log("CameraManager UI flag isPaused=true (engine pause queued)")
        sessionQueue.async { [weak self] in
            VideoDebugLog.log("CameraManager sessionQueue: begin engine.pauseRecording")
            self?.videoEngine.pauseRecording()
        }
    }

    func resumeRecording() {
        guard isRecording, isRecordingPaused else {
            VideoDebugLog.log(
                "CameraManager.resumeRecording IGNORED isRecording=\(isRecording) isPaused=\(isRecordingPaused)"
            )
            return
        }
        isRecordingPaused = false
        VideoDebugLog.log("CameraManager UI flag isPaused=false (engine resume queued)")
        sessionQueue.async { [weak self] in
            VideoDebugLog.log("CameraManager sessionQueue: begin engine.resumeRecording")
            self?.videoEngine.resumeRecording()
        }
    }

    func stopRecording() {
        VideoDebugLog.log("CameraManager.stopRecording isRecording=\(isRecording)")
        guard isRecording else { return }
        isRecordingPaused = false
        VideoDebugLog.log("CameraManager stop queued (isRecording stays true until finish callback)")
        sessionQueue.async { [weak self] in
            VideoDebugLog.log("CameraManager sessionQueue: begin engine.stopRecording")
            self?.videoEngine.stopRecording()
        }
    }

    // MARK: - Private

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                if !self.isConfigured {
                    try self.configureSession()
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                self.refreshLightCapabilities()
                Task { @MainActor in
                    self.isConfigured = true
                    self.isSessionRunning = true
                }
            } catch {
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func configureSession() throws {
        guard MultiCamSupport.isSupported else {
            throw CameraError.multiCamUnsupported
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .inputPriority

        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.cameraUnavailable("front")
        }

        let backCamera = try resolveBackCamera(front: frontCamera)
        let wideFallback = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        backDevice = usesVirtualBackZoom ? backCamera : (wideFallback ?? backCamera)
        ultraWideDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
        // Virtual Dual/Triple already covers ultra-wide FOV via zoom.
        hasUltraWide = usesVirtualBackZoom
            || ultraWideDevice != nil
            || (backCamera.isVirtualDevice && backCamera.constituentDevices.contains {
                $0.deviceType == .builtInUltraWideCamera
            })

        logMultiCamDeviceSets()
        VideoDebugLog.log(
            "back=\(backCamera.deviceType.rawValue) virtual=\(backCamera.isVirtualDevice) " +
            "usesVirtualBackZoom=\(usesVirtualBackZoom) hasUltraWide=\(hasUltraWide)"
        )

        // Prefer Full HD multi-cam formats; fall back only if session cost is too high.
        try configureMultiCamFormat(for: backCamera, preferLowerCost: false)
        try configureMultiCamFormat(for: frontCamera, preferLowerCost: false)

        let backInput = try AVCaptureDeviceInput(device: backCamera)
        let frontInput = try AVCaptureDeviceInput(device: frontCamera)

        guard session.canAddInput(backInput), session.canAddInput(frontInput) else {
            // Virtual back rejected at add-time — retry once with plain Wide.
            if usesVirtualBackZoom, let wide = wideFallback, wide !== backCamera {
                VideoDebugLog.log("canAddInput failed for virtual back — falling back to wide")
                usesVirtualBackZoom = false
                backDevice = wide
                hasUltraWide = ultraWideDevice != nil
                try configureMultiCamFormat(for: wide, preferLowerCost: false)
                let wideInput = try AVCaptureDeviceInput(device: wide)
                guard session.canAddInput(wideInput), session.canAddInput(frontInput) else {
                    throw CameraError.cannotAddInput
                }
                session.addInputWithNoConnections(wideInput)
                session.addInputWithNoConnections(frontInput)
                backCameraInput = wideInput
                frontCameraInput = frontInput
                try finishSessionWiring(backDevice: wide, backInput: wideInput, frontCamera: frontCamera, frontInput: frontInput)
                return
            }
            throw CameraError.cannotAddInput
        }
        session.addInputWithNoConnections(backInput)
        session.addInputWithNoConnections(frontInput)
        backCameraInput = backInput
        frontCameraInput = frontInput

        try finishSessionWiring(backDevice: backCamera, backInput: backInput, frontCamera: frontCamera, frontInput: frontInput)
    }

    private func finishSessionWiring(
        backDevice: AVCaptureDevice,
        backInput: AVCaptureDeviceInput,
        frontCamera: AVCaptureDevice,
        frontInput: AVCaptureDeviceInput
    ) throws {
        guard let backPort = backInput.ports(
            for: .video,
            sourceDeviceType: backDevice.deviceType,
            sourceDevicePosition: backDevice.position
        ).first else {
            throw CameraError.portUnavailable("back")
        }
        guard let frontPort = frontInput.ports(
            for: .video,
            sourceDeviceType: frontCamera.deviceType,
            sourceDevicePosition: frontCamera.position
        ).first else {
            throw CameraError.portUnavailable("front")
        }

        backVideoPort = backPort
        frontVideoPort = frontPort

        guard session.canAddOutput(backPhotoOutput), session.canAddOutput(frontPhotoOutput) else {
            throw CameraError.cannotAddOutput
        }
        session.addOutputWithNoConnections(backPhotoOutput)
        session.addOutputWithNoConnections(frontPhotoOutput)

        let backPhotoConnection = AVCaptureConnection(inputPorts: [backPort], output: backPhotoOutput)
        let frontPhotoConnection = AVCaptureConnection(inputPorts: [frontPort], output: frontPhotoOutput)
        if session.canAddConnection(backPhotoConnection) {
            session.addConnection(backPhotoConnection)
            configurePortraitRotation(backPhotoConnection)
        }
        if session.canAddConnection(frontPhotoConnection) {
            session.addConnection(frontPhotoConnection)
            configurePortraitRotation(frontPhotoConnection)
            if frontPhotoConnection.isVideoMirroringSupported {
                frontPhotoConnection.automaticallyAdjustsVideoMirroring = false
                frontPhotoConnection.isVideoMirrored = true
            }
        }

        configurePhotoOutputQuality(backPhotoOutput)
        configurePhotoOutputQuality(frontPhotoOutput)

        if let microphone = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: microphone),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
            microphoneInput = audioInput
        }

        // Leave headroom for dual video data outputs.
        if session.hardwareCost > 0.75 {
            VideoDebugLog.log("hardwareCost=\(session.hardwareCost) before video outputs — using efficient formats")
            try configureMultiCamFormat(for: backDevice, preferLowerCost: true)
            try configureMultiCamFormat(for: frontCamera, preferLowerCost: true)
            configurePhotoOutputQuality(backPhotoOutput)
            configurePhotoOutputQuality(frontPhotoOutput)
        }

        do {
            try videoEngine.configure(session: session, backPort: backPort, frontPort: frontPort)
            videoEngine.updatePrimaryBack(isPrimaryBack)
            VideoDebugLog.log("CameraManager session configured, hardwareCost=\(session.hardwareCost)")
            if session.hardwareCost >= 1.0 {
                VideoDebugLog.log("WARNING hardwareCost>=1, downgrading formats")
                try configureMultiCamFormat(for: backDevice, preferLowerCost: true)
                try configureMultiCamFormat(for: frontCamera, preferLowerCost: true)
                configurePhotoOutputQuality(backPhotoOutput)
                configurePhotoOutputQuality(frontPhotoOutput)
                VideoDebugLog.log("downgraded hardwareCost=\(session.hardwareCost)")
            }
        } catch {
            VideoDebugLog.log("ERROR videoEngine.configure failed: \(error)")
        }

        // Match UI zoom after configure (default 1× unless user already chose another level).
        applyPendingZoom(animated: false)
        refreshLightCapabilities()
    }

    /// Prefer Triple → DualWide when multi-cam allows pairing with the front camera.
    private func resolveBackCamera(front: AVCaptureDevice) throws -> AVCaptureDevice {
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera
        ]

        for type in preferredTypes {
            guard let candidate = AVCaptureDevice.default(type, for: .video, position: .back) else {
                VideoDebugLog.log("back candidate \(type.rawValue) unavailable")
                continue
            }
            guard candidate.formats.contains(where: \.isMultiCamSupported) else {
                VideoDebugLog.log("back candidate \(type.rawValue) has no multi-cam formats")
                continue
            }
            guard isMultiCamPairSupported(back: candidate, front: front) else {
                VideoDebugLog.log("back candidate \(type.rawValue) not in supportedMultiCamDeviceSets with front")
                continue
            }
            usesVirtualBackZoom = candidate.isVirtualDevice
            return candidate
        }

        usesVirtualBackZoom = false
        guard let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.cameraUnavailable("back")
        }
        return wide
    }

    private func isMultiCamPairSupported(back: AVCaptureDevice, front: AVCaptureDevice) -> Bool {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera,
                .builtInTrueDepthCamera
            ],
            mediaType: .video,
            position: .unspecified
        )
        let needed = Set([back, front])
        return discovery.supportedMultiCamDeviceSets.contains { $0.isSuperset(of: needed) }
    }

    private func logMultiCamDeviceSets() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera,
                .builtInTrueDepthCamera
            ],
            mediaType: .video,
            position: .unspecified
        )
        if discovery.supportedMultiCamDeviceSets.isEmpty {
            VideoDebugLog.log("supportedMultiCamDeviceSets empty")
            return
        }
        for set in discovery.supportedMultiCamDeviceSets {
            let names = set
                .map { "\($0.deviceType.rawValue)" }
                .sorted()
                .joined(separator: "+")
            VideoDebugLog.log("multiCamSet {\(names)}")
        }
    }

    /// Maps UI zoom chips to the virtual-device zoom space (UW at min, Wide at first switch-over).
    private func videoZoomFactor(for level: ZoomLevel, on device: AVCaptureDevice) -> CGFloat {
        let minZoom = device.minAvailableVideoZoomFactor
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        let wideFactor = switchOvers.first ?? max(minZoom, 1.0)

        switch level {
        case .half:
            return minZoom
        case .one:
            return wideFactor
        case .two:
            return wideFactor * 2
        }
    }

    private func configurePortraitRotation(_ connection: AVCaptureConnection) {
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    private func configureMultiCamFormat(for device: AVCaptureDevice, preferLowerCost: Bool = false) throws {
        let multiCamFormats = device.formats.filter(\.isMultiCamSupported)
        guard !multiCamFormats.isEmpty else { return }

        func videoPixels(_ format: AVCaptureDevice.Format) -> Int {
            let d = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return Int(d.width) * Int(d.height)
        }

        func photoPixels(_ format: AVCaptureDevice.Format) -> Int {
            format.supportedMaxPhotoDimensions
                .map { Int($0.width) * Int($0.height) }
                .max() ?? videoPixels(format)
        }

        // Cap video stream at 1080p-class for dual-cam stability.
        // Prefer usable video resolution first — DualWide can expose a multi-cam
        // format with huge stills but only 640×480 video (that used to win).
        let maxVideoPixels = 1920 * 1080
        let minPreferredPixels = 1280 * 720

        let selected: AVCaptureDevice.Format
        if preferLowerCost {
            let ranked = multiCamFormats.sorted { videoPixels($0) < videoPixels($1) }
            selected = ranked.first(where: { videoPixels($0) >= minPreferredPixels }) ?? ranked[0]
        } else {
            let underCap = multiCamFormats.filter { videoPixels($0) <= maxVideoPixels }
            let pool = underCap.isEmpty ? multiCamFormats : underCap
            let preferred = pool.filter { videoPixels($0) >= minPreferredPixels }
            let rankedPool = preferred.isEmpty ? pool : preferred
            selected = rankedPool.max { lhs, rhs in
                let lv = videoPixels(lhs)
                let rv = videoPixels(rhs)
                if lv != rv { return lv < rv }
                let lp = photoPixels(lhs)
                let rp = photoPixels(rhs)
                if lp != rp { return lp < rp }
                if lhs.isHighPhotoQualitySupported != rhs.isHighPhotoQualitySupported {
                    return !lhs.isHighPhotoQualitySupported && rhs.isHighPhotoQualitySupported
                }
                return false
            } ?? rankedPool[0]
        }

        let dims = CMVideoFormatDescriptionGetDimensions(selected.formatDescription)
        let photoDims = selected.supportedMaxPhotoDimensions.max(by: {
            Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
        })
        VideoDebugLog.log(
            """
            activeFormat \(device.position == .back ? "back" : "front") \
            video=\(dims.width)x\(dims.height) \
            photo=\(photoDims.map { "\($0.width)x\($0.height)" } ?? "n/a") \
            highPhoto=\(selected.isHighPhotoQualitySupported) lowCost=\(preferLowerCost)
            """
        )

        try device.lockForConfiguration()
        device.activeFormat = selected
        if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 30 }) {
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        } else if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 24 }) {
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 24)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 24)
        }
        device.unlockForConfiguration()
    }

    private func configurePhotoOutputQuality(_ output: AVCapturePhotoOutput) {
        output.maxPhotoQualityPrioritization = .quality

        let device = output.connections
            .flatMap(\.inputPorts)
            .compactMap { $0.input as? AVCaptureDeviceInput }
            .map(\.device)
            .first

        guard let format = device?.activeFormat else { return }
        let supported = format.supportedMaxPhotoDimensions
        guard let best = supported.max(by: {
            Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
        }) else { return }

        output.maxPhotoDimensions = best
        VideoDebugLog.log("photo maxDimensions \(best.width)x\(best.height)")
    }

    private func makePhotoSettings(for output: AVCapturePhotoOutput) -> AVCapturePhotoSettings {
        let settings: AVCapturePhotoSettings
        if output.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }
        settings.photoQualityPrioritization = .quality
        let maxDimensions = output.maxPhotoDimensions
        if maxDimensions.width > 0, maxDimensions.height > 0 {
            settings.maxPhotoDimensions = maxDimensions
        }
        if output.supportedFlashModes.contains(.on) {
            switch flashMode {
            case .off: settings.flashMode = .off
            case .on: settings.flashMode = .on
            case .auto: settings.flashMode = .auto
            }
        }
        return settings
    }

    private func switchBackCamera(to device: AVCaptureDevice, preferredZoom: CGFloat) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let current = backCameraInput {
            session.removeInput(current)
        }

        do {
            try configureMultiCamFormat(for: device, preferLowerCost: false)
            let newInput = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(newInput) else { return }
            session.addInputWithNoConnections(newInput)
            backCameraInput = newInput
            if device.deviceType == .builtInWideAngleCamera {
                backDevice = device
            }

            guard let port = newInput.ports(
                for: .video,
                sourceDeviceType: device.deviceType,
                sourceDevicePosition: device.position
            ).first else { return }
            backVideoPort = port

            reconnectOutputs(to: port)
            configurePhotoOutputQuality(backPhotoOutput)
            // Instant settle after device switch — preview already interrupted by reconfigure.
            applyZoom(on: device, factor: max(preferredZoom, 1.0), animated: false)
            refreshLightCapabilities()
        } catch {
            Task { @MainActor in
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func reconnectOutputs(to port: AVCaptureInput.Port) {
        for connection in backPhotoOutput.connections {
            session.removeConnection(connection)
        }
        let photoConnection = AVCaptureConnection(inputPorts: [port], output: backPhotoOutput)
        if session.canAddConnection(photoConnection) {
            session.addConnection(photoConnection)
            configurePortraitRotation(photoConnection)
        }
        videoEngine.reconnectBack(port: port, session: session)
    }

    private func applyZoom(on device: AVCaptureDevice, factor: CGFloat, animated: Bool = true) {
        do {
            try device.lockForConfiguration()
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = min(device.maxAvailableVideoZoomFactor, device.activeFormat.videoMaxZoomFactor, 16)
            let target = min(max(factor, minZoom), maxZoom)
            if animated, abs(device.videoZoomFactor - target) > 0.01 {
                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }
                // Zoom factors per second — a bit faster helps UW ↔ Wide lens handoff.
                device.ramp(toVideoZoomFactor: target, withRate: 5.0)
            } else {
                device.videoZoomFactor = target
            }
            device.unlockForConfiguration()
        } catch {
            Task { @MainActor in
                self.errorMessage = "Unable to set zoom: \(error.localizedDescription)"
            }
        }
    }

    private func handleDualPhoto(image: UIImage?, isBack: Bool) {
        photoLock.lock()
        defer { photoLock.unlock() }

        guard let image else { return }

        if isBack {
            if isPrimaryBack {
                pendingPrimaryImage = image
            } else {
                pendingSecondaryImage = image
            }
        } else {
            if isPrimaryBack {
                pendingSecondaryImage = image
            } else {
                pendingPrimaryImage = image
            }
        }

        guard let primary = pendingPrimaryImage,
              let secondary = pendingSecondaryImage,
              let layout = activeLayoutContext else { return }

        pendingPrimaryImage = nil
        pendingSecondaryImage = nil
        activeLayoutContext = nil
        dualPhotoDelegates.removeAll()

        let composed = DualImageCompositor.compose(
            primary: primary,
            secondary: secondary,
            context: layout
        )

        Task { @MainActor in
            self.lastCapturedImage = composed
            self.photoCaptureCount += 1
            self.saveImageToPhotos(composed)
        }
    }

    private func saveImageToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }

            let directory = FileManager.default.temporaryDirectory
            let heicURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("heic")
            let jpegURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")

            let fileURL: URL?
            if image.writeHEIC(to: heicURL, compressionQuality: 0.92) {
                fileURL = heicURL
            } else if image.writeJPEG(to: jpegURL, compressionQuality: 1.0) {
                fileURL = jpegURL
            } else {
                fileURL = nil
            }

            guard let fileURL else {
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
            } completionHandler: { _, _ in
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    private func saveVideoToPhotos(_ url: URL) {
        // Thumbnail + gallery pulse before the temp file is removed.
        let thumbnail = Self.makeVideoThumbnail(from: url)
        Task { @MainActor in
            if let thumbnail {
                self.lastCapturedImage = thumbnail
                self.photoCaptureCount += 1
            }
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { _, _ in
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private static func makeVideoThumbnail(from url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 240)
        let time = CMTime(seconds: 0.05, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

enum CameraError: LocalizedError {
    case multiCamUnsupported
    case cameraUnavailable(String)
    case cannotAddInput
    case cannotAddOutput
    case portUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .multiCamUnsupported:
            MultiCamSupport.unsupportedMessage
        case .cameraUnavailable(let position):
            "Unable to access the \(position) camera."
        case .cannotAddInput:
            "Unable to add camera input to the capture session."
        case .cannotAddOutput:
            "Unable to add capture output to the session."
        case .portUnavailable(let position):
            "Video port unavailable for the \(position) camera."
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil else {
            completion(nil)
            return
        }

        // Prefer uncompressed bitmap when available — avoids an extra decode round-trip.
        if let cgImage = photo.cgImageRepresentation() {
            let orientation = Self.imageOrientation(from: photo)
            completion(UIImage(cgImage: cgImage, scale: 1, orientation: orientation))
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        completion(image)
    }

    private static func imageOrientation(from photo: AVCapturePhoto) -> UIImage.Orientation {
        guard let raw = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
              let cgOrientation = CGImagePropertyOrientation(rawValue: raw) else {
            return .up
        }
        switch cgOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        }
    }
}
