//
//  TopBarView.swift
//  Dual Camera
//

import SwiftUI

struct TopBarView: View {
    @Bindable var viewModel: CameraViewModel

    var body: some View {
        HStack(spacing: 18) {
            Button {
                viewModel.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
            }

            Spacer()

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
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.55), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func overlayButton(title: String?, systemImage: String, overlay: ActiveOverlay) -> some View {
        Button {
            viewModel.toggleOverlay(overlay)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                if let title {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(viewModel.activeOverlay == overlay ? Color.white.opacity(0.25) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
