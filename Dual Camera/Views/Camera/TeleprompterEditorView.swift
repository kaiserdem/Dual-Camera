//
//  TeleprompterEditorView.swift
//  Dual Camera
//

import SwiftUI
import UIKit

/// Full-screen editor for composing and configuring the teleprompter script.
struct TeleprompterEditorView: View {

    @Bindable var settings: AppSettings

    @Environment(\.dismiss) private var dismiss

    /// Local draft so text is committed when leaving via Back.
    @State private var draftText: String = ""
    @State private var showClearConfirm: Bool = false

    private let fontSizeStep: Double = 2

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        editorSection
                        speedSection
                        fontSizeSection
                        autoStartSection
                        delaySection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
            }
        }
        .onAppear {
            draftText = settings.teleprompterText
        }
        .confirmationDialog(
            "Очистити текст?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Очистити", role: .destructive) { draftText = "" }
            Button("Скасувати", role: .cancel) {}
        }
        .interactiveDismissDisabled()
        .preferredColorScheme(.dark)
    }

    // MARK: - Header (matches SettingsView)

    private var header: some View {
        ZStack {
            Text("Суфлер")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            HStack {
                Button {
                    commitAndDismiss()
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
    }

    // MARK: - Sections

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Текст скрипту", systemImage: "doc.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TeleprompterScriptTextEditor(text: $draftText)
                .frame(minHeight: 180)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    Group {
                        if draftText.isEmpty {
                            Text("Вставте або введіть текст для суфлера…")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .padding(16)
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                )

            HStack {
                Text("\(draftText.count) символів")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showClearConfirm = true
                } label: {
                    Label("Очистити", systemImage: "trash")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .disabled(draftText.isEmpty)
            }
        }
    }

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Швидкість прокрутки", systemImage: "gauge.with.dots.needle.67percent")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "tortoise.fill")
                    .foregroundStyle(.secondary)
                Slider(value: $settings.teleprompterSpeed, in: 0.2...3.0, step: 0.1)
                    .tint(.yellow)
                Image(systemName: "hare.fill")
                    .foregroundStyle(.secondary)
            }

            Text(String(format: "%.1f×", settings.teleprompterSpeed))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Розмір шрифту", systemImage: "textformat.size")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                fontSizeButton(
                    title: "A−",
                    accessibilityLabel: "Зменшити шрифт",
                    isEnabled: settings.teleprompterFontSize > 12
                ) {
                    adjustFontSize(by: -fontSizeStep)
                }

                Text("\(Int(settings.teleprompterFontSize.rounded()))")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 44)
                    .accessibilityLabel("Розмір шрифту \(Int(settings.teleprompterFontSize.rounded()))")

                fontSizeButton(
                    title: "A+",
                    accessibilityLabel: "Збільшити шрифт",
                    isEnabled: settings.teleprompterFontSize < 48
                ) {
                    adjustFontSize(by: fontSizeStep)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var autoStartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $settings.teleprompterAutoStartWithRecording) {
                Label("Автостарт з записом", systemImage: "record.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(.yellow)

            Text("Увімкнути суфлер автоматично, коли починається запис відео.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var delaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Затримка старту", systemImage: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Затримка старту", selection: $settings.teleprompterStartDelaySeconds) {
                ForEach(AppSettings.teleprompterDelayOptions, id: \.self) { seconds in
                    Text(seconds == 0 ? "0 с" : "\(seconds) с")
                        .tag(seconds)
                }
            }
            .pickerStyle(.segmented)

            Text("Відлік перед початком прокрутки. Текст видно одразу.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Helpers

    private func fontSizeButton(
        title: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.45))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private func adjustFontSize(by delta: Double) {
        settings.teleprompterFontSize = AppSettings.clampedTeleprompterFontSize(
            settings.teleprompterFontSize + delta
        )
    }

    /// Save draft and leave. Does **not** start the teleprompter overlay —
    /// that happens via recording toggle, auto-start, or the teleprompter button.
    private func commitAndDismiss() {
        settings.teleprompterText = draftText
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    TeleprompterEditorView(settings: AppSettings())
}

// MARK: - Script editor (Return / Done dismisses keyboard)

private struct TeleprompterScriptTextEditor: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.keyboardAppearance = .dark
        textView.returnKeyType = .done
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.text = text
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            if replacement == "\n" {
                textView.resignFirstResponder()
                return false
            }
            return true
        }
    }
}
