//
//  RatioOverlayView.swift
//  Dual Camera
//

import SwiftUI

struct RatioOverlayView: View {
    @Bindable var viewModel: CameraViewModel

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AspectRatio.allCases) { ratio in
                Button {
                    viewModel.selectedRatio = ratio
                } label: {
                    Text(ratio.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.selectedRatio == ratio ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(viewModel.selectedRatio == ratio ? Color.white : Color.white.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
