//
//  BottomBarView.swift
//  Dual Camera
//

import SwiftUI

struct BottomBarView: View {
    @Bindable var viewModel: CameraViewModel

    var body: some View {
        VStack(spacing: 14) {
            zoomSelector

            HStack(spacing: 28) {
                if viewModel.isRecording {
                    pauseButton
                } else {
                    galleryButton
                }
                shutterButton
                // Solo Main/Front: keep invisible placeholder so shutter stays centered.
                // Dual layouts: show swap as before.
                swapButton
                    .opacity(viewModel.selectedLayout.usesSingleCamera ? 0 : 1)
                    .allowsHitTesting(!viewModel.selectedLayout.usesSingleCamera)
                    .accessibilityHidden(viewModel.selectedLayout.usesSingleCamera)
            }

            modeSelector
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    private var zoomSelector: some View {
        // Front camera has no optical/digital zoom control in this app — keep the row
        // for spacing but make chips invisible so the bottom bar does not jump.
        let showsZoom = viewModel.selectedLayout != .frontOnly
        let isEnabled = viewModel.isZoomControlEnabled && showsZoom
        return HStack(spacing: 10) {
            ForEach(ZoomLevel.allCases) { level in
                let isSelected = viewModel.selectedZoom == level
                Button {
                    viewModel.selectZoom(level)
                } label: {
                    Text(level.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(
                            isEnabled
                                ? (isSelected ? .black : .white)
                                : .white.opacity(0.35)
                        )
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(
                                    isEnabled
                                        ? (isSelected ? Color.yellow : Color.white.opacity(0.12))
                                        : Color.white.opacity(0.06)
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
            }
        }
        .opacity(showsZoom ? 1 : 0)
        .allowsHitTesting(showsZoom)
        .accessibilityHidden(!showsZoom)
    }

    private var galleryButton: some View {
        Button {
            viewModel.openGallery()
        } label: {
            Group {
                if let image = viewModel.galleryThumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(.white.opacity(0.8), lineWidth: 1)
                        )
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                }
            }
            .scaleEffect(viewModel.galleryPulseScale)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Gallery")
    }

    private var pauseButton: some View {
        Button {
            VideoDebugLog.markTap(viewModel.isRecordingPaused ? "UI.resumeButton" : "UI.pauseButton")
            VideoDebugLog.log("BottomBar pause/resume tapped isPaused=\(viewModel.isRecordingPaused)")
            viewModel.toggleRecordingPause()
        } label: {
            Image(systemName: viewModel.isRecordingPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.isRecordingPaused ? "Resume Recording" : "Pause Recording")
    }

    private var shutterButton: some View {
        Button {
            let action: String
            if viewModel.captureMode == .photo {
                action = "UI.shutterPhoto"
            } else if viewModel.isRecording {
                action = "UI.shutterStop"
            } else {
                action = "UI.shutterStart"
            }
            VideoDebugLog.markTap(action)
            VideoDebugLog.log(
                "BottomBar shutter tapped mode=\(viewModel.captureMode.rawValue) isRecording=\(viewModel.isRecording)"
            )
            viewModel.handleShutter()
        } label: {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 74, height: 74)

                Circle()
                    .fill(shutterFill)
                    .frame(width: viewModel.isRecording ? 32 : 62, height: viewModel.isRecording ? 32 : 62)
                    .clipShape(RoundedRectangle(cornerRadius: viewModel.isRecording ? 6 : 31, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.captureMode == .photo ? "Take Photo" : "Toggle Recording")
    }

    private var shutterFill: Color {
        if viewModel.captureMode == .video {
            return viewModel.isRecording ? .red : .red.opacity(0.95)
        }
        return .white
    }

    private var swapButton: some View {
        Button {
            viewModel.swapCameras()
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
                .opacity(viewModel.isLayoutLocked ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLayoutLocked)
        .accessibilityLabel("Swap Cameras")
        .accessibilityHint(viewModel.isLayoutLocked ? "Unavailable while recording" : "")
    }

    private var modeSelector: some View {
        HStack(spacing: 8) {
            ForEach(CaptureMode.allCases) { mode in
                Button {
                    viewModel.captureMode = mode
                    if mode == .photo, viewModel.isRecording {
                        viewModel.handleShutter()
                    }
                } label: {
                    Text(mode.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(viewModel.captureMode == mode ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(viewModel.captureMode == mode ? Color.white : Color.white.opacity(0.12))
                        )
                        .overlay {
                            if viewModel.captureMode == mode {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.yellow.opacity(0.85), lineWidth: 1.5)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
