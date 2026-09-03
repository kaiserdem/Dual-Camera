//
//  CameraPreviewView.swift
//  Dual Camera
//

import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureMultiCamSession
    let inputPort: AVCaptureInput.Port?
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.setSessionWithNoConnection(session)
        view.previewLayer.videoGravity = videoGravity
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.videoGravity = videoGravity
        uiView.previewLayer.setSessionWithNoConnection(session)
        uiView.attach(port: inputPort)
    }

    static func dismantleUIView(_ uiView: PreviewUIView, coordinator: ()) {
        uiView.detach()
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        private var attachedPort: AVCaptureInput.Port?

        func attach(port: AVCaptureInput.Port?) {
            guard let port else {
                VideoDebugLog.log("preview.attach nil port → detach")
                detach()
                return
            }

            if attachedPort === port, previewLayer.connection != nil {
                return
            }

            guard let session = previewLayer.session as? AVCaptureMultiCamSession else {
                VideoDebugLog.log("preview.attach ERROR no multi-cam session on layer")
                return
            }

            VideoDebugLog.log(
                "preview.attach begin port=\(ObjectIdentifier(port)) " +
                "sessionRunning=\(session.isRunning)"
            )

            session.beginConfiguration()
            defer { session.commitConfiguration() }

            detachCurrentConnection(in: session)
            freePreviewConnections(for: port, in: session)

            let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: previewLayer)
            guard session.canAddConnection(connection) else {
                VideoDebugLog.log("preview.attach ERROR canAddConnection=false")
                attachedPort = nil
                return
            }

            session.addConnection(connection)
            configureMirroring(on: connection, for: port)
            attachedPort = port
            VideoDebugLog.log("preview.attach OK")
        }

        func detach() {
            guard let session = previewLayer.session as? AVCaptureMultiCamSession else {
                attachedPort = nil
                return
            }

            VideoDebugLog.log("preview.detach")
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            detachCurrentConnection(in: session)
        }

        private func detachCurrentConnection(in session: AVCaptureMultiCamSession) {
            if let existing = previewLayer.connection {
                session.removeConnection(existing)
            }
            attachedPort = nil
        }

        /// A port can feed only one preview layer. Steal it before reattaching on swap.
        private func freePreviewConnections(for port: AVCaptureInput.Port, in session: AVCaptureMultiCamSession) {
            for connection in session.connections {
                let usesPort = connection.inputPorts.contains { $0 === port }
                let isPreview = connection.videoPreviewLayer != nil
                if usesPort && isPreview {
                    session.removeConnection(connection)
                }
            }
        }

        private func configureMirroring(on connection: AVCaptureConnection, for port: AVCaptureInput.Port) {
            guard connection.isVideoMirroringSupported else { return }
            let isFront = (port.input as? AVCaptureDeviceInput)?.device.position == .front
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isFront
        }
    }
}
