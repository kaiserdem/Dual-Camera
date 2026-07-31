//
//  TopBarView.swift
//  Dual Camera
//

import SwiftUI

struct TopBarView: View {
    @Bindable var viewModel: CameraViewModel

    var body: some View {
        Group {
            if viewModel.isRecording {
                RecordingTopBarView(viewModel: viewModel)
            } else {
                IdleTopBarView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
    }
}

private struct IdleTopBarView: View {
    @Bindable var viewModel: CameraViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")

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
            .padding(.vertical, 10)
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

    var body: some View {
        HStack {
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
