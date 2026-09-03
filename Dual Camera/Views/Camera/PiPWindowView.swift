//
//  PiPWindowView.swift
//  Dual Camera
//

import SwiftUI

struct PiPWindowView: View {
    @Bindable var viewModel: CameraViewModel
    let containerSize: CGSize

    /// Live center while dragging — avoids @Observable updates every frame (lag / flicker).
    @State private var liveDragCenter: CGPoint?
    @State private var dragAnchor: CGPoint?
    @State private var pinchStartScale: CGFloat?

    private var pipSize: CGSize {
        let width = containerSize.width * viewModel.pipScale * viewModel.pipShape.widthMultiplier
        return CGSize(width: width, height: width * viewModel.pipShape.heightMultiplier)
    }

    private var cornerRadius: CGFloat {
        min(pipSize.width, pipSize.height) * 0.12
    }

    private var defaultPosition: CGPoint {
        CaptureLayoutContext.defaultPiPCenter(
            in: containerSize,
            shape: viewModel.pipShape,
            scale: viewModel.pipScale
        )
    }

    private var restingPosition: CGPoint {
        viewModel.pipPosition ?? defaultPosition
    }

    private var displayPosition: CGPoint {
        liveDragCenter ?? restingPosition
    }

    var body: some View {
        styledPip
            .frame(width: pipSize.width, height: pipSize.height)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !viewModel.isLayoutLocked else { return }
                viewModel.swapCameras()
            }
            .position(displayPosition)
            .gesture(viewModel.isLayoutLocked ? nil : interactionGestures)
            .onChange(of: containerSize) { _, newSize in
                if liveDragCenter == nil {
                    clampStoredPosition(in: newSize)
                }
            }
            .onChange(of: viewModel.pipShape) { _, _ in
                cancelLiveDrag()
                viewModel.pipPosition = nil
            }
            .onChange(of: viewModel.isPiPRounded) { _, _ in
                if liveDragCenter == nil {
                    clampStoredPosition(in: containerSize)
                }
            }
            .onChange(of: viewModel.pipScale) { _, _ in
                if liveDragCenter == nil {
                    clampStoredPosition(in: containerSize)
                }
            }
    }

    private var interactionGestures: some Gesture {
        dragGesture.simultaneously(with: magnificationGesture)
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
        DragGesture(minimumDistance: 4, coordinateSpace: .named("viewfinder"))
            .onChanged { value in
                guard !viewModel.isLayoutLocked else { return }
                guard pinchStartScale == nil else { return }

                if dragAnchor == nil {
                    dragAnchor = restingPosition
                }
                guard let anchor = dragAnchor else { return }

                liveDragCenter = clamp(
                    CGPoint(
                        x: anchor.x + value.translation.width,
                        y: anchor.y + value.translation.height
                    ),
                    in: containerSize
                )
            }
            .onEnded { _ in
                if let final = liveDragCenter {
                    viewModel.pipPosition = final
                }
                cancelLiveDrag()
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard !viewModel.isLayoutLocked else { return }
                // Ignore single-finger noise that used to reset drag and cause flicker.
                guard abs(value - 1.0) > 0.04 else { return }

                if pinchStartScale == nil {
                    pinchStartScale = viewModel.pipScale
                    cancelLiveDrag()
                }
                guard let start = pinchStartScale else { return }
                viewModel.pipScale = start * value
            }
            .onEnded { _ in
                pinchStartScale = nil
                clampStoredPosition(in: containerSize)
            }
    }

    private func cancelLiveDrag() {
        liveDragCenter = nil
        dragAnchor = nil
    }

    private func clampStoredPosition(in size: CGSize) {
        guard let current = viewModel.pipPosition else { return }
        viewModel.pipPosition = clamp(current, in: size)
    }

    private func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let width = size.width * viewModel.pipScale * viewModel.pipShape.widthMultiplier
        let height = width * viewModel.pipShape.heightMultiplier
        let halfWidth = width / 2
        let halfHeight = height / 2
        let inset = CaptureLayoutContext.pipEdgeInset
        return CGPoint(
            x: min(max(point.x, halfWidth + inset), size.width - halfWidth - inset),
            y: min(max(point.y, halfHeight + inset), size.height - halfHeight - inset)
        )
    }
}
