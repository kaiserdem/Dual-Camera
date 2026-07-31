//
//  SettingsView.swift
//  Dual Camera
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    private let rateURL = URL(string: "https://apps.apple.com/app/id000000000")!
    private let privacyURL = URL(string: "https://example.com/privacy")!
    private let termsURL = URL(string: "https://example.com/terms")!
    private let contactURL = URL(string: "mailto:support@example.com")!
    private let shareText = "Check out Dual Camera — shoot with front and back cameras at once!"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Soft dual-cam glow behind content — same black stage as the viewfinder.
            RadialGradient(
                colors: [
                    Color.yellow.opacity(0.08),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        dualMarkHeader

                        appearanceCard

                        videoExportCard

                        actionsCard

                        aboutCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Settings")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.9), .black.opacity(0.35), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Brand mark

    private var dualMarkHeader: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.55), .purple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 96)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.85), .pink.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 42)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                    }
                    .offset(x: 10, y: 8)
            }
            .frame(width: 88, height: 108)

            VStack(alignment: .leading, spacing: 6) {
                Text("Dual Camera")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text("Two lenses. One take.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                Text(exportSummary)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(panelBackground)
    }

    private var exportSummary: String {
        "\(settings.videoResolution.title) · \(settings.videoCodec.subtitle) · \(settings.videoContainer.title)"
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Appearance",
                subtitle: "Camera screen look"
            )

            Toggle(isOn: $settings.isFloatingCameraChromeEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Floating panels")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Frosted top & bottom bars with edge insets")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .tint(.yellow)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )

            Toggle(isOn: $settings.isFullBleedCameraBackgroundEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Camera background")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Fill the screen with live preview instead of black")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .tint(.yellow)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
        }
        .padding(16)
        .background(panelBackground)
    }

    // MARK: - Video export

    private var videoExportCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: "Video Export",
                subtitle: "Applies to the next recording"
            )

            optionBlock(title: "Codec") {
                HStack(spacing: 8) {
                    ForEach(VideoCodecOption.allCases) { option in
                        selectableChip(
                            title: option.subtitle,
                            detail: option == .hevc ? "Smaller" : "Compatible",
                            isSelected: settings.videoCodec == option
                        ) {
                            settings.videoCodec = option
                        }
                    }
                }
            }

            optionBlock(title: "Container") {
                HStack(spacing: 8) {
                    ForEach(VideoContainerOption.allCases) { option in
                        selectableChip(
                            title: option.title,
                            detail: option == .mp4 ? "Share-ready" : "Apple native",
                            isSelected: settings.videoContainer == option
                        ) {
                            settings.videoContainer = option
                        }
                    }
                }
            }

            optionBlock(title: "Resolution") {
                HStack(spacing: 8) {
                    ForEach(VideoResolutionOption.allCases) { option in
                        selectableChip(
                            title: option.title,
                            detail: option == .p1080 ? "Detail" : "Lighter",
                            isSelected: settings.videoResolution == option
                        ) {
                            settings.videoResolution = option
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(panelBackground)
    }

    // MARK: - Actions

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "More", subtitle: nil)

            HStack(spacing: 10) {
                Link(destination: rateURL) {
                    actionTile(title: "Rate", systemImage: "star.fill", accent: .yellow)
                }

                ShareLink(item: shareText) {
                    actionTile(title: "Share", systemImage: "square.and.arrow.up", accent: .white)
                }

                Link(destination: contactURL) {
                    actionTile(title: "Contact", systemImage: "envelope.fill", accent: .cyan)
                }
            }
        }
        .padding(16)
        .background(panelBackground)
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "About", subtitle: "Legal & app info")

            VStack(spacing: 8) {
                Link(destination: privacyURL) {
                    legalRow(
                        title: "Privacy Policy",
                        subtitle: "How we handle data",
                        systemImage: "hand.raised.fill",
                        accent: .cyan
                    )
                }

                Link(destination: termsURL) {
                    legalRow(
                        title: "Terms of Use",
                        subtitle: "Rules for using Dual Camera",
                        systemImage: "doc.text.fill",
                        accent: .white
                    )
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.yellow.opacity(0.9))

                Text("Version")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer(minLength: 0)

                Text(appVersionLabel)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .padding(16)
        .background(panelBackground)
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let build, build != version {
            return "\(version) (\(build))"
        }
        return version
    }

    private func legalRow(
        title: String,
        subtitle: String,
        systemImage: String,
        accent: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }

    // MARK: - Building blocks

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
    }

    private func sectionHeader(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func optionBlock<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.45))
            content()
        }
    }

    private func selectableChip(
        title: String,
        detail: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .opacity(isSelected ? 0.7 : 0.55)
            }
            .foregroundStyle(isSelected ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.12))
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.yellow.opacity(0.85), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func actionTile(title: String, systemImage: String, accent: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView(settings: AppSettings())
    }
    .preferredColorScheme(.dark)
}
