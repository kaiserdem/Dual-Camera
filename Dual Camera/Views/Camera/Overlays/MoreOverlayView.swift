//
//  MoreOverlayView.swift
//  Dual Camera
//

import SwiftUI

struct MoreOverlayView: View {
    @Bindable var viewModel: CameraViewModel

    var body: some View {
        HStack(spacing: 12) {
            toggleChip(
                title: "Flash",
                systemImage: viewModel.isFlashEnabled ? "bolt.fill" : "bolt.slash.fill",
                isActive: viewModel.isFlashEnabled
            ) {
                viewModel.isFlashEnabled.toggle()
            }

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

    private func toggleChip(
        title: String,
        systemImage: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isActive ? .yellow : .white)
            .frame(width: 78, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? Color.yellow.opacity(0.18) : Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}
