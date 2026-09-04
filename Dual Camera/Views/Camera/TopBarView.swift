//
//  TopBarView.swift
//  Dual Camera
//

import SwiftUI

struct TopBarView: View {
    @Bindable var viewModel: CameraViewModel
    @State private var collapseDragOffset: CGFloat = 0

    private let collapseThreshold: CGFloat = -28

    var body: some View {
        Group {
            if viewModel.isRecording {
                RecordingTopBarView(viewModel: viewModel)
            } else if viewModel.isTopBarCollapsed {
                collapsedPill
            } else {
                expandedIdleBar
            }
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.isRecording)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: viewModel.isTopBarCollapsed)
    }

    // MARK: - Collapsed

    private var collapsedPill: some View {
        Button {
            viewModel.isTopBarCollapsed = false
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 44, height: 28)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show top bar")
        .gesture(expandDragGesture)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Expanded idle

    private var expandedIdleBar: some View {
        IdleTopBarView(viewModel: viewModel) {
            viewModel.isTopBarCollapsed = true
        }
        .offset(y: min(collapseDragOffset, 0))
        .opacity(1 + Double(min(collapseDragOffset, 0)) / 80)
        .highPriorityGesture(collapseDragGesture)
    }

    // MARK: - Gestures

    private var collapseDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // Only upward drag collapses.
                collapseDragOffset = min(0, value.translation.height)
            }
            .onEnded { value in
                let shouldCollapse = value.translation.height < collapseThreshold
                    || value.predictedEndTranslation.height < collapseThreshold * 1.5
                collapseDragOffset = 0
                if shouldCollapse {
                    viewModel.isTopBarCollapsed = true
                    viewModel.dismissOverlay()
                }
            }
    }

    private var expandDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                if value.translation.height > 20
                    || value.predictedEndTranslation.height > 36 {
                    viewModel.isTopBarCollapsed = false
                }
            }
    }
}

private struct IdleTopBarView: View {
    @Bindable var viewModel: CameraViewModel
    var onCollapse: () -> Void

    private let controlHeight: CGFloat = 40

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCollapse) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: controlHeight, height: controlHeight)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide top bar")

            Spacer(minLength: 8)

            overlayButton(
                title: viewModel.selectedRatio.title,
                systemImage: "aspectratio",
                overlay: .ratio
            )

            overlayButton(
                title: nil,
                systemImage: "rectangle.on.rectangle",
                overlay: .layout
            )

            overlayButton(
                title: nil,
                systemImage: "ellipsis",
                overlay: .more
            )

            Button {
                viewModel.handleTeleprompterButtonTap()
            } label: {
                Image(systemName: viewModel.settings.isTeleprompterActive ? "text.alignleft" : "doc.text")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(viewModel.settings.isTeleprompterActive ? .yellow : .white)
                    .frame(width: controlHeight, height: controlHeight)
                    .background(
                        Circle()
                            .fill(
                                viewModel.settings.isTeleprompterActive
                                    ? Color.yellow.opacity(0.22)
                                    : Color.white.opacity(0.12)
                            )
                    )
                    .overlay {
                        if viewModel.settings.isTeleprompterActive {
                            Circle()
                                .stroke(Color.yellow.opacity(0.75), lineWidth: 1.5)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.settings.isTeleprompterActive ? "Teleprompter active" : "Open teleprompter")

            Button {
                viewModel.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: controlHeight, height: controlHeight)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func overlayButton(title: String?, systemImage: String, overlay: ActiveOverlay) -> some View {
        Button {
            viewModel.toggleOverlay(overlay)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                if let title {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: controlHeight)
            .background(
                Capsule()
                    .fill(viewModel.activeOverlay == overlay ? Color.white.opacity(0.22) : Color.white.opacity(0.12))
            )
            .overlay {
                if viewModel.activeOverlay == overlay {
                    Capsule()
                        .stroke(Color.yellow.opacity(0.75), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RecordingTopBarView: View {
    @Bindable var viewModel: CameraViewModel

    private let controlHeight: CGFloat = 40

    var body: some View {
        HStack {
            Color.clear
                .frame(width: controlHeight, height: controlHeight)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .opacity(viewModel.isRecordingPaused ? 0.4 : 1)

                Text(viewModel.formattedRecordingTime)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
            )

            Spacer(minLength: 0)

            Button {
                viewModel.handleTeleprompterButtonTap()
            } label: {
                Image(systemName: viewModel.settings.isTeleprompterActive ? "text.alignleft" : "doc.text")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(viewModel.settings.isTeleprompterActive ? .yellow : .white)
                    .frame(width: controlHeight, height: controlHeight)
                    .background(
                        Circle()
                            .fill(
                                viewModel.settings.isTeleprompterActive
                                    ? Color.yellow.opacity(0.22)
                                    : Color.white.opacity(0.12)
                            )
                    )
                    .overlay {
                        if viewModel.settings.isTeleprompterActive {
                            Circle()
                                .stroke(Color.yellow.opacity(0.75), lineWidth: 1.5)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                viewModel.settings.isTeleprompterActive
                    ? "Hide teleprompter"
                    : "Show teleprompter"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
