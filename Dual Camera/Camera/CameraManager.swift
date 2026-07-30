//
//  CameraManager.swift
//  Dual Camera
//

import AVFoundation
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
    private(set) var lastCapturedImage: UIImage?
    private(set) var isMultiCamAvailable = MultiCamSupport.isSupported
    private(set) var isPrimaryBack = true
    private(set) var hasUltraWide = false

    var errorMessage: String?
    var flashMode: FlashModeOption = .off

    private let sessionQueue = DispatchQueue(label: "com.dualcamera.session")
    private let backPhotoOutput = AVCapturePhotoOutput()
    private let frontPhotoOutput = AVCapturePhotoOutput()
    private let movieFileOutput = AVCaptureMovieFileOutput()

    private var backCameraInput: AVCaptureDeviceInput?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var microphoneInput: AVCaptureDeviceInput?
    private var backDevice: AVCaptureDevice?
    private var ultraWideDevice: AVCaptureDevice?
    private var photoDelegate: PhotoCaptureDelegate?
    private var movieDelegate: MovieRecordingDelegate?

    var primaryVideoPort: AVCaptureInput.Port? {
        isPrimaryBack ? backVideoPort : frontVideoPort
    }

    var secondaryVideoPort: AVCaptureInput.Port? {
        isPrimaryBack ? frontVideoPort : backVideoPort
    }

    func prepare() {
        guard isMultiCamAvailable else {
            errorMessage = MultiCamSupport.unsupportedMessage
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.configureAndStart()
                    } else {
                        self?.errorMessage = "Camera access is required to use Dual Camera."
                    }
                }
            }
        default:
            errorMessage = "Camera access is required to use Dual Camera."
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }

    func swapCameras() {
        isPrimaryBack.toggle()
    }

    func setZoom(_ level: ZoomLevel) {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if level == .half, let ultraWide = self.ultraWideDevice, self.hasUltraWide {
                self.switchBackCamera(to: ultraWide, preferredZoom: 1.0)
                return
            }

            guard let device = self.backDevice else { return }
            if level == .half && !self.hasUltraWide {
                Task { @MainActor in
                    self.applyZoom(on: device, factor: 1.0)
                }
                return
            }

            if self.backCameraInput?.device !== device {
                self.switchBackCamera(to: device, preferredZoom: level.factor)
            } else {
                self.applyZoom(on: device, factor: max(level.factor, 1.0))
            }
        }
    }

    func setTorchEnabled(_ enabled: Bool) {
        sessionQueue.async { [weak self] in
            guard let device = self?.backDevice, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = enabled ? .on : .off
                device.unlockForConfiguration()
            } catch {
                Task { @MainActor in
                    self?.errorMessage = "Unable to change torch: \(error.localizedDescription)"
                }
            }
        }
    }

    func takePhoto() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let output = self.isPrimaryBack ? self.backPhotoOutput : self.frontPhotoOutput
            guard let connection = output.connection(with: .video), connection.isEnabled else {
                Task { @MainActor in
                    self.errorMessage = "Photo capture is not available."
                }
                return
            }

            let settings = AVCapturePhotoSettings()
            if output.supportedFlashModes.contains(.on) {
                switch self.flashMode {
                case .off: settings.flashMode = .off
                case .on: settings.flashMode = .on
                case .auto: settings.flashMode = .auto
                }
            }

            let delegate = PhotoCaptureDelegate { [weak self] image in
                Task { @MainActor in
                    guard let self else { return }
                    self.photoDelegate = nil
                    if let image {
                        self.lastCapturedImage = image
                        self.saveImageToPhotos(image)
                    }
                }
            }
            self.photoDelegate = delegate
            output.capturePhoto(with: settings, delegate: delegate)
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.movieFileOutput.isRecording else { return }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")

            let delegate = MovieRecordingDelegate { [weak self] url in
                Task { @MainActor in
                    guard let self else { return }
                    self.movieDelegate = nil
                    self.isRecording = false
                    if let url {
                        self.saveVideoToPhotos(url)
                    }
                }
            }
            self.movieDelegate = delegate
            self.movieFileOutput.startRecording(to: tempURL, recordingDelegate: delegate)
            Task { @MainActor in
                self.isRecording = true
            }
        }
    }

    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self, self.movieFileOutput.isRecording else { return }
            self.movieFileOutput.stopRecording()
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

        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.cameraUnavailable("back")
        }
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.cameraUnavailable("front")
        }

        backDevice = backCamera
        ultraWideDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
        hasUltraWide = ultraWideDevice != nil

        let backInput = try AVCaptureDeviceInput(device: backCamera)
        let frontInput = try AVCaptureDeviceInput(device: frontCamera)

        guard session.canAddInput(backInput), session.canAddInput(frontInput) else {
            throw CameraError.cannotAddInput
        }
        session.addInputWithNoConnections(backInput)
        session.addInputWithNoConnections(frontInput)
        backCameraInput = backInput
        frontCameraInput = frontInput

        guard let backPort = backInput.ports(
            for: .video,
            sourceDeviceType: backCamera.deviceType,
            sourceDevicePosition: backCamera.position
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
        }
        if session.canAddConnection(frontPhotoConnection) {
            session.addConnection(frontPhotoConnection)
            if frontPhotoConnection.isVideoMirroringSupported {
                frontPhotoConnection.automaticallyAdjustsVideoMirroring = false
                frontPhotoConnection.isVideoMirrored = true
            }
        }

        if session.canAddOutput(movieFileOutput) {
            session.addOutputWithNoConnections(movieFileOutput)
            let movieConnection = AVCaptureConnection(inputPorts: [backPort], output: movieFileOutput)
            if session.canAddConnection(movieConnection) {
                session.addConnection(movieConnection)
            }
        }

        if let microphone = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: microphone),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
            microphoneInput = audioInput
        }

        try configureMultiCamFormat(for: backCamera)
        try configureMultiCamFormat(for: frontCamera)
    }

    private func configureMultiCamFormat(for device: AVCaptureDevice) throws {
        let multiCamFormats = device.formats.filter(\.isMultiCamSupported)
        guard let format = multiCamFormats.last else { return }
        try device.lockForConfiguration()
        device.activeFormat = format
        device.unlockForConfiguration()
    }

    private func switchBackCamera(to device: AVCaptureDevice, preferredZoom: CGFloat) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let current = backCameraInput {
            session.removeInput(current)
        }

        do {
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
            applyZoom(on: device, factor: max(preferredZoom, 1.0))
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
        }

        for connection in movieFileOutput.connections where connection.inputPorts.contains(where: { $0.mediaType == .video }) {
            session.removeConnection(connection)
        }
        let movieConnection = AVCaptureConnection(inputPorts: [port], output: movieFileOutput)
        if session.canAddConnection(movieConnection) {
            session.addConnection(movieConnection)
        }
    }

    private func applyZoom(on device: AVCaptureDevice, factor: CGFloat) {
        do {
            try device.lockForConfiguration()
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10)
            device.videoZoomFactor = min(max(factor, 1.0), maxZoom)
            device.unlockForConfiguration()
        } catch {
            Task { @MainActor in
                self.errorMessage = "Unable to set zoom: \(error.localizedDescription)"
            }
        }
    }

    private func saveImageToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }
    }

    private func saveVideoToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { _, _ in
                try? FileManager.default.removeItem(at: url)
            }
        }
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

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        completion(image)
    }
}

private final class MovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    private let completion: (URL?) -> Void

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        completion(error == nil ? outputFileURL : nil)
    }
}
