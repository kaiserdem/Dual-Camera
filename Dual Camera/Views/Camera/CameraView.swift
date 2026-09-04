//
//  CameraView.swift
//  Dual Camera
//

import SwiftUI

struct CameraView: View {
    @State private var viewModel = CameraViewModel()
    @Environment(\.scenePhase) private var scenePhase

    private var usesFloatingChrome: Bool {
        viewModel.effectiveFloatingChrome
    }

    private var usesFullBleedCameraBackground: Bool {
        viewModel.effectiveFullBleedBackground
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    Color.black.ignoresSafeArea()

                    // Keep one viewfinder identity across appearance modes so preview
                    // layers are not destroyed when Floating panels / background toggles.
                    viewfinderSection()

                    // Chrome owns TopBar / BottomBar (zoom+shutter). Teleprompter sits
                    // in the middle slot between them so it never covers zoom controls.
                    chromeOverlay

                    if viewModel.showsCameraLoadingIndicator {
                        cameraLoadingOverlay
                    }

                    if viewModel.activeOverlay != .none {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture {
                                viewModel.dismissOverlay()
                            }
                    }

                    overlayPanel()
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
            .onChange(of: viewModel.showSettings) { _, isShowing in
                if isShowing {
                    viewModel.onSettingsOpened()
                } else {
                    viewModel.onSettingsClosed()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                viewModel.handleScenePhase(newPhase)
            }
            .onChange(of: viewModel.isRecording) { _, isRecording in
                viewModel.syncRecordingTimer(isRecording: isRecording)
                if isRecording {
                    viewModel.dismissOverlay()
                    viewModel.isTopBarCollapsed = false
                    viewModel.handleTeleprompterRecordingStarted()
                } else {
                    viewModel.handleTeleprompterRecordingStopped()
                }
            }
            .onChange(of: viewModel.photoCaptureCount) { _, count in
                guard count > 0 else { return }
                viewModel.triggerGalleryCapturePulse()
            }
            .onChange(of: viewModel.isFlashControlAvailable) { _, available in
                if !available {
                    viewModel.syncFlashHardware()
                }
            }
            .fullScreenCover(isPresented: $viewModel.showTeleprompterEditor) {
                TeleprompterEditorView(settings: viewModel.settings)
            }
            .onChange(of: viewModel.isSessionRunning) { _, running in
                VideoDebugLog.log("UI isSessionRunning → \(running)")
                if running {
                    viewModel.isCameraWarmingUp = false
                    viewModel.syncCameraPowerPolicy()
                }
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

    // MARK: - Layouts

    /// Bars only — viewfinder lives in the parent ZStack so it stays stable.
    @ViewBuilder
    private var chromeOverlay: some View {
        if usesFloatingChrome {
            floatingChromeBars
        } else if usesFullBleedCameraBackground {
            classicFullBleedChromeBars
        } else {
            classicChromeBars
        }
    }

    private var floatingChromeBars: some View {
        VStack(spacing: 0) {
            TopBarView(viewModel: viewModel)
                .modifier(TopBarChromeModifier(
                    usesFloatingChrome: true,
                    isCollapsed: viewModel.isTopBarCollapsed && !viewModel.isRecording
                ))
                .padding(.horizontal, 16)
                .padding(.top, 8)

            chromeMiddleSlot

            BottomBarView(viewModel: viewModel)
                .cameraFloatingPanel()
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var classicFullBleedChromeBars: some View {
        VStack(spacing: 0) {
            TopBarView(viewModel: viewModel)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.55), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.top, 0)

            chromeMiddleSlot

            BottomBarView(viewModel: viewModel)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.bottom, 35)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// Classic letterbox: opaque bars cover the stage edges (camera stays underneath).
    private var classicChromeBars: some View {
        VStack(spacing: 0) {
            TopBarView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .padding(.top, 0)

            chromeMiddleSlot

            BottomBarView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .padding(.bottom, 35)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// Space between TopBar and BottomBar (zoom / shutter). Teleprompter fills it entirely.
    @ViewBuilder
    private var chromeMiddleSlot: some View {
        if viewModel.settings.isTeleprompterActive {
            teleprompterOverlay
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Spacer(minLength: 0)
                .allowsHitTesting(false)
        }
    }

    private var cameraLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.2)
                Text("Starting camera…")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
        }
        .allowsHitTesting(false)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showsCameraLoadingIndicator)
    }

    /// Space reserved so Fit / framed ratios sit between floating chrome panels.
    private var chromeTopInset: CGFloat {
        if usesFloatingChrome {
            return viewModel.isTopBarCollapsed ? 40 : 72
        }
        if usesFullBleedCameraBackground {
            return 0
        }
        // Classic letterbox — keep stage away from opaque bars.
        return viewModel.isTopBarCollapsed ? 52 : 64
    }

    private var chromeBottomInset: CGFloat {
        if usesFloatingChrome {
            return 200
        }
        if usesFullBleedCameraBackground {
            return 0
        }
        return 160
    }

    /// Live capture stage.
    /// Full sits edge-to-edge under floating chrome (Z-order below bars). Other modes unchanged.
    private func viewfinderSection() -> some View {
        GeometryReader { proxy in
            let isFull = viewModel.selectedRatio == .fill
            let useChromeInsets = usesFloatingChrome || !usesFullBleedCameraBackground
            let topInset: CGFloat = (useChromeInsets && !isFull) ? chromeTopInset : 0
            let bottomInset: CGFloat = (useChromeInsets && !isFull) ? chromeBottomInset : 0
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
    private func overlayPanel() -> some View {
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
            .transition(.move(edge: .top).combined(with: .opacity))

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.activeOverlay)
    }

    // MARK: - Teleprompter

    private var teleprompterOverlay: some View {
        TeleprompterView(
            text: viewModel.settings.teleprompterText,
            speed: Bindable(viewModel.settings).teleprompterSpeed,
            fontSize: viewModel.settings.teleprompterFontSize,
            startDelaySeconds: viewModel.settings.teleprompterStartDelaySeconds,
            isPlaying: Bindable(viewModel.settings).isTeleprompterScrolling,
            onClose: {
                viewModel.deactivateTeleprompter()
            }
        )
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: viewModel.settings.isTeleprompterActive)
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
