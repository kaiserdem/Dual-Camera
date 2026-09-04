//
//  LayoutOverlayView.swift
//  Dual Camera
//

import SwiftUI

struct LayoutOverlayView: View {
    @Bindable var viewModel: CameraViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Layout")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CameraLayout.allCases) { layout in
                        selectableChip(
                            title: layout.title,
                            systemImage: layout.systemImage,
                            isSelected: viewModel.selectedLayout == layout
                        ) {
                            viewModel.selectedLayout = layout
                        }
                    }
                }
            }

            if viewModel.selectedLayout == .pip {
                sectionTitle("PiP Shape")
                HStack(spacing: 8) {
                    ForEach(PiPShape.allCases) { shape in
                        selectableChip(
                            title: shape.title,
                            systemImage: nil,
                            isSelected: viewModel.pipShape == shape
                        ) {
                            viewModel.pipShape = shape
                        }
                    }
                }

                if viewModel.pipShape.supportsRoundedCorners {
                    Toggle(
                        "Rounded",
                        isOn: Binding(
                            get: { viewModel.isPiPRounded },
                            set: { viewModel.isPiPRounded = $0 }
                        )
                    )
                    .tint(.cyan)
                    .foregroundStyle(.white)
                }
            }

            // Border / separator only apply to dual layouts.
            if !viewModel.selectedLayout.usesSingleCamera {
                sectionTitle(viewModel.selectedLayout == .pip ? "Border" : "Separator")
                Toggle(
                    viewModel.selectedLayout == .pip ? "Border" : "Separator",
                    isOn: Binding(
                        get: { viewModel.isBorderEnabled },
                        set: { viewModel.isBorderEnabled = $0 }
                    )
                )
                .tint(.cyan)

                if viewModel.isBorderEnabled {
                    HStack {
                        Text("Width")
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            viewModel.decreaseBorderWidth()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        Text("\(Int(viewModel.borderWidth))")
                            .foregroundStyle(.white)
                            .frame(minWidth: 24)
                        Button {
                            viewModel.increaseBorderWidth()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                    .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        ForEach(BorderLineStyle.allCases) { lineStyle in
                            selectableChip(
                                title: lineStyle.title,
                                systemImage: lineStyle.systemImage,
                                isSelected: viewModel.borderLineStyle == lineStyle
                            ) {
                                viewModel.borderLineStyle = lineStyle
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        ForEach(BorderStyle.allCases) { style in
                            Button {
                                viewModel.applyBorderPreset(style)
                            } label: {
                                Circle()
                                    .fill(style.color)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Circle()
                                            .stroke(
                                                .white,
                                                lineWidth: viewModel.borderColor.isApproximatelyEqual(to: style.color) ? 2 : 0
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                        }

                        ColorPicker(
                            "Custom border color",
                            selection: Binding(
                                get: { viewModel.borderColor },
                                set: { viewModel.borderColor = $0 }
                            ),
                            supportsOpacity: true
                        )
                        .labelsHidden()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.85), lineWidth: 1)
                        }
                        .accessibilityLabel("Custom border color")
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
    }

    private func selectableChip(
        title: String,
        systemImage: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.18))
            )
        }
        .buttonStyle(.plain)
    }
}
