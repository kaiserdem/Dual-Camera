//
//  CameraView.swift
//  Dual Camera
//

import SwiftUI

struct CameraView: View {
    @State private var viewModel = CameraViewModel()

    var body: some View {
        NavigationStack {
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

                overlayPanel
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $viewModel.showSettings) {
                SettingsView()
            }
            .onAppear {
                viewModel.onAppear()
            }
            .onDisappear {
                viewModel.onDisappear()
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
                .clipShape(RoundedRectangle(cornerRadius: 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }

    @ViewBuilder
    private var overlayPanel: some View {
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
            .transition(.move(edge: .top).combined(with: .opacity))

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.activeOverlay)
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
