//
//  ViewfinderView.swift
//  Dual Camera
//

import SwiftUI

struct ViewfinderView: View {
    @Bindable var viewModel: CameraViewModel

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                switch viewModel.selectedLayout {
                case .pip:
                    pipLayout(size: size)
                case .verticalSplit:
                    splitLayout(axis: .horizontal, size: size)
                case .horizontalSplit:
                    splitLayout(axis: .vertical, size: size)
                }

                if viewModel.isGridEnabled {
                    GridOverlayView()
                }

                if viewModel.isLevelerEnabled {
                    LevelerOverlayView(roll: viewModel.levelerRoll)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    @ViewBuilder
    private func pipLayout(size: CGSize) -> some View {
        primaryPreview
            .frame(width: size.width, height: size.height)

        PiPWindowView(viewModel: viewModel, containerSize: size)
    }

    @ViewBuilder
    private func splitLayout(axis: Axis, size: CGSize) -> some View {
        Group {
            if axis == .horizontal {
                HStack(spacing: 2) {
                    primaryPreview
                    secondaryPreview
                }
            } else {
                VStack(spacing: 2) {
                    primaryPreview
                    secondaryPreview
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.swapCameras()
        }
    }

    @ViewBuilder
    private var primaryPreview: some View {
        if viewModel.isSessionRunning, let port = viewModel.primaryPort {
            CameraPreviewView(session: viewModel.session, inputPort: port)
        } else {
            placeholder(colors: [.blue.opacity(0.75), .purple.opacity(0.65)], symbol: "camera.fill")
        }
    }

    @ViewBuilder
    private var secondaryPreview: some View {
        if viewModel.isSessionRunning, let port = viewModel.secondaryPort {
            CameraPreviewView(session: viewModel.session, inputPort: port)
        } else {
            placeholder(colors: [.orange.opacity(0.8), .pink.opacity(0.7)], symbol: "person.crop.square")
        }
    }

    private func placeholder(colors: [Color], symbol: String) -> some View {
        Rectangle()
            .fill(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay {
                Image(systemName: symbol)
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.85))
            }
    }
}
