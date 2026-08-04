//
//  CameraView.swift
//  Dual Camera
//

import SwiftUI

struct CameraView: View {
    @State private var viewModel = CameraViewModel()
    @State private var overlayOffset: CGSize = .zero
    @State private var overlayDragStart: CGSize?

    private var usesFloatingChrome: Bool {
        viewModel.settings.isFloatingCameraChromeEnabled
    }

    private var usesFullBleedCameraBackground: Bool {
        viewModel.settings.isFullBleedCameraBackgroundEnabled
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    Color.black.ignoresSafeArea()

                    if usesFloatingChrome {
                        floatingChromeLayout
                    } else if usesFullBleedCameraBackground {
                        classicFullBleedChromeLayout
                    } else {
                        classicChromeLayout
                    }

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
                    viewModel.isTopBarCollapsed = false
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
        .animation(.easeInOut(duration: 0.25), value: usesFloatingChrome)
        .animation(.easeInOut(duration: 0.25), value: usesFullBleedCameraBackground)
    }

    // MARK: - Layouts

    private var floatingChromeLayout: some View {
        ZStack {
            viewfinderSection()

            VStack(spacing: 0) {
                TopBarView(viewModel: viewModel)
                    .modifier(TopBarChromeModifier(
                        usesFloatingChrome: true,
                        isCollapsed: viewModel.isTopBarCollapsed && !viewModel.isRecording
                    ))
                    .padding(.horizontal, 16)
                    .padding(.top, 13)

                Spacer(minLength: 0)
                    .allowsHitTesting(false)

                BottomBarView(viewModel: viewModel)
                    .cameraFloatingPanel()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 50)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Classic bars over an edge-to-edge camera stage (no black letterbox).
    private var classicFullBleedChromeLayout: some View {
        ZStack {
            viewfinderSection()

            VStack(spacing: 0) {
                TopBarView(viewModel: viewModel)
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0.55), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.top, 5)

                Spacer(minLength: 0)
                    .allowsHitTesting(false)

                BottomBarView(viewModel: viewModel)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.bottom, 40)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var classicChromeLayout: some View {
        VStack(spacing: 0) {
            TopBarView(viewModel: viewModel)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.55), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.top, 5)

            viewfinderSection()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomBarView(viewModel: viewModel)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.bottom, 40)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// Space reserved so Fit / framed ratios sit between floating chrome panels.
    private var chromeTopInset: CGFloat {
        viewModel.isTopBarCollapsed ? 40 : 72
    }
    private var chromeBottomInset: CGFloat { 200 }

    /// Live capture stage.
    /// Full sits edge-to-edge under floating chrome (Z-order below bars). Other modes unchanged.
    private func viewfinderSection() -> some View {
        GeometryReader { proxy in
            let isFull = viewModel.selectedRatio == .fill
            let topInset: CGFloat = (usesFloatingChrome && !isFull) ? chromeTopInset : 0
            let bottomInset: CGFloat = (usesFloatingChrome && !isFull) ? chromeBottomInset : 0
            let availableSize = CGSize(
                width: proxy.size.width,
                height: max(proxy.size.height - topInset - bottomInset, 1)
            )
            let framedSize = captureFrameSize(
                in: availableSize,
                for: viewModel.selectedRatio
            )

            ViewfinderView(viewModel: viewModel)
                .frame(width: framedSize.width, height: framedSize.height)
                .overlay {
                    Color.white
                        .opacity(viewModel.shutterFlashOpacity)
                        .allowsHitTesting(false)
                }
                .clipShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.top, topInset)
                .padding(.bottom, bottomInset)
                .background(Color.black)
                .animation(.easeInOut(duration: 0.22), value: viewModel.selectedRatio)
        }
    }

    /// Full pins to stage width (under bars). Fit / 1:1 / 4:3 / 16:9 keep existing framing.
    private func captureFrameSize(in available: CGSize, for aspect: AspectRatio) -> CGSize {
        switch aspect {
        case .full:
            return available
        case .fill:
            // Edge-to-edge width under top/bottom chrome (no 9:16 side letterbox on preview).
            return available
        case .square, .fourThree, .sixteenNine:
            guard let ratio = aspect.ratio else { return available }
            let width = available.width
            return CGSize(width: width, height: width / ratio)
        }
    }

    @ViewBuilder
    private func overlayPanel(in containerSize: CGSize) -> some View {
        VStack {
            Spacer().frame(height: usesFloatingChrome ? (viewModel.isTopBarCollapsed ? 44 : 78) : 64)

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

private extension View {
    /// Matches Settings section cards: frosted, rounded, floating over the stage.
    func cameraFloatingPanel() -> some View {
        background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }
}

/// Full floating panel while expanded; collapsed pill keeps its own compact chrome.
private struct TopBarChromeModifier: ViewModifier {
    let usesFloatingChrome: Bool
    let isCollapsed: Bool

    func body(content: Content) -> some View {
        if usesFloatingChrome && !isCollapsed {
            content.cameraFloatingPanel()
        } else {
            content
        }
    }
}
