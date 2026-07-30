//
//  PiPWindowView.swift
//  Dual Camera
//

import SwiftUI

struct PiPWindowView: View {
    @Bindable var viewModel: CameraViewModel
    let containerSize: CGSize

    @State private var dragOrigin: CGPoint?

    private var pipSize: CGSize {
        let width = containerSize.width * 0.28
        return CGSize(width: width, height: width * 1.25)
    }

    private var defaultPosition: CGPoint {
        CGPoint(
            x: containerSize.width - pipSize.width / 2 - 16,
            y: pipSize.height / 2 + 16
        )
    }

    private var position: CGPoint {
        viewModel.pipPosition ?? defaultPosition
    }

    var body: some View {
        styledPip
            .frame(width: pipSize.width, height: pipSize.height)
            .onTapGesture {
                viewModel.swapCameras()
            }
            .gesture(dragGesture)
            .position(position)
            .onChange(of: containerSize) { _, newSize in
                clampStoredPosition(in: newSize)
            }
    }

    @ViewBuilder
    private var styledPip: some View {
        switch viewModel.pipShape {
        case .square:
            pipContent
                .clipShape(Rectangle())
                .overlay { borderStroke(Rectangle()) }
                .contentShape(Rectangle())
        case .roundedSquare:
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            pipContent
                .clipShape(shape)
                .overlay { borderStroke(shape) }
                .contentShape(shape)
        case .circle:
            pipContent
                .clipShape(Circle())
                .overlay { borderStroke(Circle()) }
                .contentShape(Circle())
        }
    }

    @ViewBuilder
    private var pipContent: some View {
        if viewModel.isSessionRunning, let port = viewModel.secondaryPort {
            CameraPreviewView(session: viewModel.session, inputPort: port)
        } else {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.orange.opacity(0.8), .pink.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: "person.crop.square")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                }
        }
    }

    @ViewBuilder
    private func borderStroke<S: Shape>(_ shape: S) -> some View {
        if viewModel.isBorderEnabled {
            shape.stroke(
                viewModel.borderStyle.color,
                style: StrokeStyle(lineWidth: viewModel.borderWidth, dash: [6, 4])
            )
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let origin = dragOrigin ?? position
                if dragOrigin == nil {
                    dragOrigin = origin
                }
                let proposed = CGPoint(
                    x: origin.x + value.translation.width,
                    y: origin.y + value.translation.height
                )
                viewModel.pipPosition = clamp(proposed, in: containerSize)
            }
            .onEnded { _ in
                dragOrigin = nil
            }
    }

    private func clampStoredPosition(in size: CGSize) {
        guard let current = viewModel.pipPosition else { return }
        viewModel.pipPosition = clamp(current, in: size)
    }

    private func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let halfWidth = pipSize.width / 2
        let halfHeight = pipSize.height / 2
        return CGPoint(
            x: min(max(point.x, halfWidth + 8), size.width - halfWidth - 8),
            y: min(max(point.y, halfHeight + 8), size.height - halfHeight - 8)
        )
    }
}
