//
//  MoreOverlayView.swift
//  Dual Camera
//

import SwiftUI

struct MoreOverlayView: View {
    @Bindable var viewModel: CameraViewModel

    var body: some View {
        HStack(spacing: 12) {
            flashChip

            toggleChip(
                title: "Grid",
                systemImage: "grid",
                isActive: viewModel.isGridEnabled
            ) {
                viewModel.isGridEnabled.toggle()
            }

            toggleChip(
                title: "Leveler",
                systemImage: "level",
                isActive: viewModel.isLevelerEnabled
            ) {
                viewModel.isLevelerEnabled.toggle()
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var flashChip: some View {
        let isVideo = viewModel.captureMode == .video
        let mode = viewModel.flashMode
        let isAvailable = viewModel.isFlashControlAvailable
        let isActive = isAvailable && (isVideo ? mode == .on : mode != .off)
        let title = isVideo ? "Torch" : mode.title
        let symbol = isVideo
            ? (mode == .on ? "bolt.fill" : "bolt.slash.fill")
            : mode.systemImage
        let accessibility = !isAvailable
            ? (isVideo ? "Torch Unavailable" : "Flash Unavailable")
            : isVideo
                ? (mode == .on ? "Torch On" : "Torch Off")
                : "Flash \(mode.title)"

        return toggleChip(
            title: title,
            systemImage: symbol,
            isActive: isActive,
            isEnabled: isAvailable,
            accessibilityLabel: accessibility
        ) {
            viewModel.cycleFlashMode()
        }
    }

    private func toggleChip(
        title: String,
        systemImage: String,
        isActive: Bool,
        isEnabled: Bool = true,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isEnabled ? (isActive ? .yellow : .white) : .white.opacity(0.35))
            .frame(width: 78, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isEnabled
                            ? (isActive ? Color.yellow.opacity(0.18) : Color.white.opacity(0.12))
                            : Color.white.opacity(0.06)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}
