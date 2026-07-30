//
//  CameraView.swift
//  Dual Camera
//

import SwiftUI

struct CameraView: View {
    @State private var viewModel = CameraViewModel()
    @State private var overlayOffset: CGSize = .zero
    @State private var overlayDragStart: CGSize?

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        TopBarView(viewModel: viewModel)

                        viewfinderSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        BottomBarView(viewModel: viewModel)
                    }
                    .ignoresSafeArea(edges: .bottom)

                    if viewModel.activeOverlay != .none {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture {
                                viewModel.dismissOverlay()
                            }
                    }

                    overlayPanel(in: proxy.size)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $viewModel.showSettings) {
                SettingsView(settings: viewModel.settings)
            }
            .onAppear {
                viewModel.onAppear()
            }
            .onDisappear {
                viewModel.onDisappear()
            }
            .onChange(of: viewModel.isRecording) { _, isRecording in
                viewModel.syncRecordingTimer(isRecording: isRecording)
                if isRecording {
                    viewModel.dismissOverlay()
                }
            }
            .onChange(of: viewModel.photoCaptureCount) { _, count in
                guard count > 0 else { return }
                viewModel.triggerGalleryCapturePulse()
            }
            .alert(
                "Camera Unavailable",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
    }

    private var viewfinderSection: some View {
        GeometryReader { proxy in
            let framedSize = aspectFittedSize(
                in: proxy.size,
                ratio: viewModel.selectedRatio.ratio
            )

            ViewfinderView(viewModel: viewModel)
                .frame(width: framedSize.width, height: framedSize.height)
                .overlay {
                    Color.white
                        .opacity(viewModel.shutterFlashOpacity)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }

    @ViewBuilder
    private func overlayPanel(in containerSize: CGSize) -> some View {
        VStack {
            Spacer().frame(height: 64)

            Group {
                switch viewModel.activeOverlay {
                case .none:
                    EmptyView()
                case .ratio:
                    RatioOverlayView(viewModel: viewModel)
                case .layout:
                    LayoutOverlayView(viewModel: viewModel)
                case .more:
                    MoreOverlayView(viewModel: viewModel)
                }
            }
            .padding(.horizontal, 16)
            .offset(overlayOffset)
            .simultaneousGesture(overlayDragGesture(in: containerSize))
            .transition(.move(edge: .top).combined(with: .opacity))

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.activeOverlay)
        .onChange(of: viewModel.activeOverlay) { _, _ in
            overlayOffset = .zero
            overlayDragStart = nil
        }
    }

    private func overlayDragGesture(in containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let start = overlayDragStart ?? overlayOffset
                if overlayDragStart == nil {
                    overlayDragStart = start
                }
                overlayOffset = clampOverlayOffset(
                    CGSize(
                        width: start.width + value.translation.width,
                        height: start.height + value.translation.height
                    ),
                    in: containerSize
                )
            }
            .onEnded { _ in
                overlayDragStart = nil
            }
    }

    private func clampOverlayOffset(_ offset: CGSize, in containerSize: CGSize) -> CGSize {
        let maxX = max(containerSize.width * 0.35, 80)
        let minY: CGFloat = -40
        let maxY = max(containerSize.height * 0.55, 120)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, minY), maxY)
        )
    }

    private func aspectFittedSize(in container: CGSize, ratio: CGFloat?) -> CGSize {
        guard let ratio else { return container }

        let containerRatio = container.width / max(container.height, 1)
        if containerRatio > ratio {
            let height = container.height
            return CGSize(width: height * ratio, height: height)
        } else {
            let width = container.width
            return CGSize(width: width, height: width / ratio)
        }
    }
}

#Preview {
    CameraView()
}
