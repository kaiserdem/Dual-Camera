//
//  PiPWindowView.swift
//  Dual Camera
//

import SwiftUI

struct PiPWindowView: View {
    @Bindable var viewModel: CameraViewModel
    let containerSize: CGSize

    @State private var dragOrigin: CGPoint?
    @State private var pinchStartScale: CGFloat?

    private var pipSize: CGSize {
        let width = containerSize.width * viewModel.pipScale * viewModel.pipShape.widthMultiplier
        return CGSize(width: width, height: width * viewModel.pipShape.heightMultiplier)
    }

    private var cornerRadius: CGFloat {
        min(pipSize.width, pipSize.height) * 0.12
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
                guard !viewModel.isLayoutLocked else { return }
                viewModel.swapCameras()
            }
            .gesture(viewModel.isLayoutLocked ? nil : interactionGestures)
            .position(position)
            .onChange(of: containerSize) { _, newSize in
                clampStoredPosition(in: newSize)
            }
            .onChange(of: viewModel.pipShape) { _, _ in
                clampStoredPosition(in: containerSize)
            }
            .onChange(of: viewModel.isPiPRounded) { _, _ in
                clampStoredPosition(in: containerSize)
            }
            .onChange(of: viewModel.pipScale) { _, _ in
                clampStoredPosition(in: containerSize)
            }
    }

    private var interactionGestures: some Gesture {
        SimultaneousGesture(dragGesture, magnificationGesture)
    }

    @ViewBuilder
    private var styledPip: some View {
        switch viewModel.pipShape {
        case .circle:
            pipContent
                .clipShape(Circle())
                .overlay { borderStroke(Circle()) }
                .contentShape(Circle())
        case .square, .rectangle:
            if viewModel.isPiPRounded {
                let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                pipContent
                    .clipShape(shape)
                    .overlay { borderStroke(shape) }
                    .contentShape(shape)
            } else {
                pipContent
                    .clipShape(Rectangle())
                    .overlay { borderStroke(Rectangle()) }
                    .contentShape(Rectangle())
            }
        }
    }

    @ViewBuilder
    private var pipContent: some View {
        if viewModel.isSessionRunning, let port = viewModel.secondaryPort {
            CameraPreviewView(session: viewModel.session, inputPort: port)
                .id("pip-\(ObjectIdentifier(port))")
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
            let lineStyle = viewModel.borderLineStyle
            let stroke = StrokeStyle(
                lineWidth: viewModel.borderWidth,
                dash: lineStyle == .dashed ? [6, 4] : []
            )
            shape.stroke(viewModel.borderColor, style: stroke)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !viewModel.isLayoutLocked else { return }
                // Prefer pinch when two-finger interaction is active.
                guard pinchStartScale == nil else { return }
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

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard !viewModel.isLayoutLocked else { return }
                if pinchStartScale == nil {
                    pinchStartScale = viewModel.pipScale
                    dragOrigin = nil
                }
                guard let start = pinchStartScale else { return }
                viewModel.pipScale = start * value
            }
            .onEnded { _ in
                pinchStartScale = nil
                clampStoredPosition(in: containerSize)
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
