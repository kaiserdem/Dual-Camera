//
//  ViewfinderView.swift
//  Dual Camera
//

import AVFoundation
import SwiftUI

struct ViewfinderView: View {
    @Bindable var viewModel: CameraViewModel
    @State private var splitDragStartRatio: CGFloat?

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
            .coordinateSpace(name: "viewfinder")
            .clipped()
            .onAppear {
                viewModel.viewfinderSize = size
            }
            .onChange(of: size) { _, newSize in
                viewModel.viewfinderSize = newSize
            }
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
        let ratio = axis == .horizontal
            ? viewModel.verticalSplitRatio
            : viewModel.horizontalSplitRatio

        ZStack {
            if axis == .horizontal {
                HStack(spacing: 0) {
                    primaryPreview
                        .frame(width: size.width * ratio)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: swapIfUnlocked)

                    secondaryPreview
                        .frame(width: size.width * (1 - ratio))
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: swapIfUnlocked)
                }
            } else {
                VStack(spacing: 0) {
                    primaryPreview
                        .frame(height: size.height * ratio)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: swapIfUnlocked)

                    secondaryPreview
                        .frame(height: size.height * (1 - ratio))
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: swapIfUnlocked)
                }
            }

            splitDivider(axis: axis, size: size, ratio: ratio)
        }
        .frame(width: size.width, height: size.height)
    }

    private func splitDivider(axis: Axis, size: CGSize, ratio: CGFloat) -> some View {
        let hitSize: CGFloat = 44
        let lineWidth = max(viewModel.borderWidth, 1)
        let separatorColor = viewModel.borderColor
        let dash: [CGFloat] = viewModel.borderLineStyle == .dashed ? [8, 6] : []

        return ZStack {
            if viewModel.isBorderEnabled {
                separatorLine(axis: axis, size: size, lineWidth: lineWidth, color: separatorColor, dash: dash)
            }

            // Center grip — hidden while layout is frozen during recording.
            if !viewModel.isLayoutLocked {
                Capsule()
                    .fill(viewModel.isBorderEnabled ? separatorColor : Color.white.opacity(0.9))
                    .frame(
                        width: axis == .horizontal ? max(lineWidth + 2, 5) : 56,
                        height: axis == .horizontal ? 56 : max(lineWidth + 2, 5)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            }
        }
        .frame(
            width: axis == .horizontal ? hitSize : size.width,
            height: axis == .horizontal ? size.height : hitSize
        )
        .contentShape(Rectangle())
        .position(
            x: axis == .horizontal ? size.width * ratio : size.width / 2,
            y: axis == .horizontal ? size.height / 2 : size.height * ratio
        )
        .gesture(viewModel.isLayoutLocked ? nil : splitDragGesture(axis: axis, size: size))
        .allowsHitTesting(!viewModel.isLayoutLocked)
        .accessibilityLabel("Resize split")
        .accessibilityHint(viewModel.isLayoutLocked ? "Unavailable while recording" : "")
    }

    private func swapIfUnlocked() {
        guard !viewModel.isLayoutLocked else { return }
        viewModel.swapCameras()
    }

    @ViewBuilder
    private func separatorLine(
        axis: Axis,
        size: CGSize,
        lineWidth: CGFloat,
        color: Color,
        dash: [CGFloat]
    ) -> some View {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: dash)
        let mid: CGFloat = 22

        if axis == .horizontal {
            Path { path in
                path.move(to: CGPoint(x: mid, y: 0))
                path.addLine(to: CGPoint(x: mid, y: size.height))
            }
            .stroke(color, style: style)
            .frame(width: 44, height: size.height)
        } else {
            Path { path in
                path.move(to: CGPoint(x: 0, y: mid))
                path.addLine(to: CGPoint(x: size.width, y: mid))
            }
            .stroke(color, style: style)
            .frame(width: size.width, height: 44)
        }
    }

    private func splitDragGesture(axis: Axis, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard !viewModel.isLayoutLocked else { return }
                let currentRatio = axis == .horizontal
                    ? viewModel.verticalSplitRatio
                    : viewModel.horizontalSplitRatio
                let start = splitDragStartRatio ?? currentRatio
                if splitDragStartRatio == nil {
                    splitDragStartRatio = start
                }

                if axis == .horizontal {
                    viewModel.verticalSplitRatio = start + value.translation.width / max(size.width, 1)
                } else {
                    viewModel.horizontalSplitRatio = start + value.translation.height / max(size.height, 1)
                }
            }
            .onEnded { _ in
                splitDragStartRatio = nil
            }
    }

    private var previewGravity: AVLayerVideoGravity {
        .resizeAspectFill
    }

    @ViewBuilder
    private var primaryPreview: some View {
        if viewModel.isSessionRunning, let port = viewModel.primaryPort {
            CameraPreviewView(session: viewModel.session, inputPort: port, videoGravity: previewGravity)
                .id("primary-\(ObjectIdentifier(port))")
        } else {
            placeholder(colors: [.blue.opacity(0.75), .purple.opacity(0.65)], symbol: "camera.fill")
        }
    }

    @ViewBuilder
    private var secondaryPreview: some View {
        if viewModel.isSessionRunning, let port = viewModel.secondaryPort {
            CameraPreviewView(session: viewModel.session, inputPort: port, videoGravity: previewGravity)
                .id("secondary-\(ObjectIdentifier(port))")
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
