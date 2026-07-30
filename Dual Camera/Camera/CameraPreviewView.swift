//
//  CameraPreviewView.swift
//  Dual Camera
//

import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureMultiCamSession
    let inputPort: AVCaptureInput.Port?

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.setSessionWithNoConnection(session)
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.setSessionWithNoConnection(session)
        uiView.attach(port: inputPort)
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
            guard let port else { return }
            guard attachedPort !== port else { return }

            if let existing = previewLayer.connection,
               let session = previewLayer.session {
                session.removeConnection(existing)
            }

            guard let session = previewLayer.session as? AVCaptureMultiCamSession else { return }
            let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: previewLayer)
            if session.canAddConnection(connection) {
                session.addConnection(connection)
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = (port.input as? AVCaptureDeviceInput)?.device.position == .front
                }
                attachedPort = port
            }
        }
    }
}
