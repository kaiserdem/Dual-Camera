//
//  DeveloperSettingsCard.swift
//  Dual Camera
//

import PhotosUI
import SwiftUI

/// Developer-only controls (screenshot mocks). Remove or gate with `#if DEBUG` before release.
struct DeveloperSettingsCard: View {
    @Bindable var settings: AppSettings

    @State private var backPhotoItem: PhotosPickerItem?
    @State private var frontPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Developer",
                subtitle: "App Store screenshot staging"
            )

            Toggle(isOn: $settings.isDeveloperModeEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Developer mode")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Internal tools — not for production users")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .tint(.yellow)

            if settings.isDeveloperModeEnabled {
                Toggle(isOn: $settings.isDeveloperScreenshotModeEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gallery camera mocks")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Replace live previews with two photos from your library")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .tint(.yellow)

                mockPickerRow(
                    title: "Back / main camera",
                    subtitle: "Full-screen background in PiP layout",
                    image: settings.developerMockBackImage,
                    slot: .back,
                    pickerItem: $backPhotoItem
                )

                mockPickerRow(
                    title: "Front / PiP camera",
                    subtitle: "Small window or split secondary feed",
                    image: settings.developerMockFrontImage,
                    slot: .front,
                    pickerItem: $frontPhotoItem
                )

                statusLine
            }
        }
        .padding(16)
        .background(panelBackground)
        .onChange(of: backPhotoItem) { _, item in
            Task { await importPhoto(item, slot: .back) }
        }
        .onChange(of: frontPhotoItem) { _, item in
            Task { await importPhoto(item, slot: .front) }
        }
    }

    private var statusLine: some View {
        let ready = settings.hasDeveloperScreenshotMocks
        return HStack(spacing: 8) {
            Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ready ? .green : .yellow)
            Text(
                ready
                    ? "Mocks ready — open the camera screen to frame screenshots."
                    : "Pick both photos to enable mock previews."
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.55))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func mockPickerRow(
        title: String,
        subtitle: String,
        image: UIImage?,
        slot: MockSlot,
        pickerItem: Binding<PhotosPickerItem?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                thumbnail(image)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                PhotosPicker(selection: pickerItem, matching: .images) {
                    pickerButtonLabel(title: image == nil ? "Choose photo" : "Replace")
                }

                if image != nil {
                    Button("Clear") {
                        clear(slot: slot)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
    }

    private func thumbnail(_ image: UIImage?) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
    }

    private func pickerButtonLabel(title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.yellow)
            )
    }

    private enum MockSlot {
        case back
        case front
    }

    private func importPhoto(_ item: PhotosPickerItem?, slot: MockSlot) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await MainActor.run {
            switch slot {
            case .back:
                settings.setDeveloperMockBackImage(image)
            case .front:
                settings.setDeveloperMockFrontImage(image)
            }
        }
    }

    private func clear(slot: MockSlot) {
        switch slot {
        case .back:
            settings.clearDeveloperMockBackImage()
            backPhotoItem = nil
        case .front:
            settings.clearDeveloperMockFrontImage()
            frontPhotoItem = nil
        }
    }

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
}
