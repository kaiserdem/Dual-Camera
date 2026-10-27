//
//  CameraPreviewSource.swift
//  Dual Camera
//

import AVFoundation
import SwiftUI
#if DEBUG
import UIKit
#endif

/// Chooses live `CameraPreviewView` or a gallery still when developer screenshot mode is on.
enum CameraPreviewSource {
    @ViewBuilder
    static func layer(
        viewModel: CameraViewModel,
        role: MockCameraRole,
        videoGravity: AVLayerVideoGravity = .resizeAspectFill
    ) -> some View {
#if DEBUG
        if let mock = mockImage(viewModel: viewModel, role: role) {
            MockCameraPreviewView(image: mock.image, mirrored: mock.mirrored)
        } else if viewModel.isSessionRunning, let port = livePort(viewModel: viewModel, role: role) {
            CameraPreviewView(session: viewModel.session, inputPort: port, videoGravity: videoGravity)
                .id("\(role)-\(ObjectIdentifier(port))")
        } else {
            CameraPreviewPlaceholder(role: role)
        }
#else
        if viewModel.isSessionRunning, let port = livePort(viewModel: viewModel, role: role) {
            CameraPreviewView(session: viewModel.session, inputPort: port, videoGravity: videoGravity)
                .id("\(role)-\(ObjectIdentifier(port))")
        } else {
            CameraPreviewPlaceholder(role: role)
        }
#endif
    }

#if DEBUG
    private static func mockImage(viewModel: CameraViewModel, role: MockCameraRole) -> (image: UIImage, mirrored: Bool)? {
        guard viewModel.settings.isDeveloperScreenshotModeEnabled else { return nil }
        switch physicalCamera(viewModel: viewModel, role: role) {
        case .back:
            guard let image = viewModel.settings.developerMockBackImage else { return nil }
            return (image, false)
        case .front:
            guard let image = viewModel.settings.developerMockFrontImage else { return nil }
            return (image, true)
        }
    }
#endif

    private static func livePort(viewModel: CameraViewModel, role: MockCameraRole) -> AVCaptureInput.Port? {
        switch physicalCamera(viewModel: viewModel, role: role) {
        case .back: viewModel.backPort
        case .front: viewModel.frontPort
        }
    }

    private static func physicalCamera(viewModel: CameraViewModel, role: MockCameraRole) -> PhysicalCamera {
        switch role {
        case .primary:
            return viewModel.isPrimaryBack ? .back : .front
        case .secondary:
            return viewModel.isPrimaryBack ? .front : .back
        case .back:
            return .back
        case .front:
            return .front
        }
    }
}

enum MockCameraRole {
    case primary
    case secondary
    case back
    case front
}

private enum PhysicalCamera {
    case back
    case front
}

private struct CameraPreviewPlaceholder: View {
    let role: MockCameraRole

    var body: some View {
        let isBack = role == .back || role == .primary
        Rectangle()
            .fill(
                LinearGradient(
                    colors: isBack
                        ? [.blue.opacity(0.75), .purple.opacity(0.65)]
                        : [.orange.opacity(0.8), .pink.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: isBack ? "camera.fill" : "person.crop.square")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.85))
            }
    }
}
