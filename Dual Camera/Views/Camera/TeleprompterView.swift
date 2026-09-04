//
//  TeleprompterView.swift
//  Dual Camera
//

import Combine
import SwiftUI

/// Full mid-stage teleprompter: fills all space between top and bottom chrome.
/// Only the text lane and compact controls participate in hit testing.
struct TeleprompterView: View {

    // MARK: - Input

    let text: String
    @Binding var speed: Double          // multiplier 0.2 … 3.0
    var fontSize: Double = 28
    /// Seconds to count down before scrolling starts (0 = immediate).
    var startDelaySeconds: Int = 0
    @Binding var isPlaying: Bool
    var onClose: () -> Void

    // MARK: - Internal state

    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var containerHeight: CGFloat = 0

    @State private var dragStartSpeed: Double?
    @State private var showSpeedFeedback: Bool = false
    @State private var speedFeedbackHideTask: Task<Void, Never>?

    @State private var countdownRemaining: Int = 0
    @State private var countdownTask: Task<Void, Never>?
    /// True after the activation countdown has finished (pause/resume must not restart it).
    @State private var didCompleteStartDelay: Bool = false

    /// Points per second at speed == 1.0.
    private let baseScrollRate: CGFloat = 40

    /// Vertical points of drag that map to +1.0 / −1.0 speed change.
    private let dragPointsPerSpeedUnit: CGFloat = 80

    private let speedRange: ClosedRange<Double> = 0.2...3.0

    private var effectiveRate: CGFloat { baseScrollRate * CGFloat(speed) }

    /// Scroll only while playing and after the start countdown finishes.
    private var canScroll: Bool {
        guard isPlaying else { return false }
        if startDelaySeconds <= 0 { return true }
        return didCompleteStartDelay && countdownRemaining == 0
    }

    var body: some View {
        teleprompterBand
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                beginStartSequenceIfNeeded()
            }
            .onChange(of: isPlaying) { _, playing in
                if playing {
                    beginStartSequenceIfNeeded()
                } else {
                    pauseCountdown()
                }
            }
            .onDisappear {
                cancelCountdown()
            }
    }

    // MARK: - Full mid-stage band

    private var teleprompterBand: some View {
        ZStack(alignment: .topTrailing) {
            textLane
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.38))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onTapGesture {
                    isPlaying.toggle()
                }
                .gesture(speedDragGesture)

            if countdownRemaining > 0 {
                countdownOverlay
            }

            compactControls
                .padding(.top, 8)
                .padding(.trailing, 8)

            if showSpeedFeedback {
                speedFeedbackLabel
            }
        }
    }

    private var compactControls: some View {
        VStack(spacing: 10) {
            closeButton
            playPauseButton
        }
    }

    private var countdownOverlay: some View {
        Text("\(countdownRemaining)")
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.7), radius: 8, x: 0, y: 2)
            .padding(24)
            .background(.black.opacity(0.45), in: Circle())
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Countdown \(countdownRemaining)")
    }

    // MARK: - Countdown

    private func beginStartSequenceIfNeeded() {
        guard isPlaying else {
            pauseCountdown()
            return
        }

        if didCompleteStartDelay {
            countdownRemaining = 0
            return
        }

        // Countdown already in progress.
        if countdownTask != nil { return }

        let delay = max(0, startDelaySeconds)
        if delay == 0 {
            didCompleteStartDelay = true
            countdownRemaining = 0
            return
        }

        // Fresh activation, or resume after pause mid-countdown.
        if countdownRemaining <= 0 {
            countdownRemaining = delay
        }
        runCountdownTask()
    }

    private func runCountdownTask() {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            while countdownRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                countdownRemaining -= 1
            }
            didCompleteStartDelay = true
            countdownTask = nil
        }
    }

    /// Stop the timer without discarding remaining seconds (pause mid-countdown).
    private func pauseCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func cancelCountdown() {
        pauseCountdown()
        countdownRemaining = 0
        didCompleteStartDelay = false
    }

    // MARK: - Speed gesture

    private var speedDragGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                // Prefer vertical drags so diagonal / horizontal noise is ignored.
                guard abs(value.translation.height) >= abs(value.translation.width) else { return }

                if dragStartSpeed == nil {
                    dragStartSpeed = speed
                    speedFeedbackHideTask?.cancel()
                    showSpeedFeedback = true
                }

                let start = dragStartSpeed ?? speed
                // Swipe up (negative height) → faster; swipe down → slower.
                let delta = Double(-value.translation.height / dragPointsPerSpeedUnit)
                let raw = start + delta
                let stepped = (raw * 10).rounded() / 10
                speed = min(max(stepped, speedRange.lowerBound), speedRange.upperBound)
            }
            .onEnded { _ in
                dragStartSpeed = nil
                scheduleHideSpeedFeedback()
            }
    }

    private func scheduleHideSpeedFeedback() {
        speedFeedbackHideTask?.cancel()
        speedFeedbackHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showSpeedFeedback = false
            }
        }
    }

    // MARK: - Subviews

    private var speedFeedbackLabel: some View {
        Text(String(format: "%.1f×", speed))
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var textLane: some View {
        GeometryReader { proxy in
            let cHeight = proxy.size.height
            // Leave space for compact controls on the trailing edge.
            let textWidth = max(0, proxy.size.width - 16 - 52)

            // `fixedSize(vertical: true)` lets Text lay out its FULL height instead of
            // being clipped to the GeometryReader bounds (which truncated long scripts).
            Text(text.isEmpty ? "Введіть текст суфлера в редакторі…" : text)
                .font(.system(size: fontSize, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.85), radius: 4, x: 0, y: 2)
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .frame(width: textWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 16)
                .padding(.trailing, 52)
                .padding(.vertical, 12)
                .background(
                    GeometryReader { textProxy in
                        Color.clear
                            .onAppear {
                                updateContentHeight(textProxy.size.height, container: cHeight)
                            }
                            .onChange(of: textProxy.size.height) { _, h in
                                updateContentHeight(h, container: cHeight)
                            }
                    }
                )
                .offset(y: scrollOffset)
                .onAppear {
                    containerHeight = cHeight
                }
                .onChange(of: proxy.size.height) { _, h in
                    containerHeight = h
                }
                .onChange(of: text) { _, _ in
                    // Remeasure after script edits; keep start-from-bottom behavior.
                    scrollOffset = cHeight
                }
                .onChange(of: fontSize) { _, _ in
                    scrollOffset = cHeight
                }
        }
        .clipped()
        .allowsHitTesting(false)
        .onReceive(
            Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
        ) { _ in
            guard canScroll else { return }
            let delta = effectiveRate / 60.0
            scrollOffset -= delta
            // Reset when text scrolled fully past top
            if scrollOffset < -(contentHeight + containerHeight) {
                scrollOffset = containerHeight
            }
        }
    }

    private func updateContentHeight(_ height: CGFloat, container: CGFloat) {
        let wasUnmeasured = contentHeight == 0
        contentHeight = height
        containerHeight = container
        // First layout: start with the top of the script at the bottom of the band.
        if wasUnmeasured {
            scrollOffset = container
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 26, weight: .medium))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.45))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close teleprompter")
    }

    private var playPauseButton: some View {
        Button {
            isPlaying.toggle()
        } label: {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 30, weight: .regular))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.45))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause scrolling" : "Resume scrolling")
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var speed = 1.0
    @Previewable @State var isPlaying = true
    ZStack {
        Color.gray
        TeleprompterView(
            text: "Це тестовий текст суфлера. Він буде автоматично прокручуватися знизу вгору під час запису відео.",
            speed: $speed,
            fontSize: 28,
            startDelaySeconds: 3,
            isPlaying: $isPlaying,
            onClose: {}
        )
        .padding(.vertical, 80)
    }
}
