//
//  BottomBarView.swift
//  Dual Camera
//

import SwiftUI

struct BottomBarView: View {
    @Bindable var viewModel: CameraViewModel

    var body: some View {
        VStack(spacing: 16) {
            zoomSelector

            HStack(spacing: 28) {
                if viewModel.isRecording {
                    pauseButton
                } else {
                    galleryButton
                }
                shutterButton
                swapButton
            }

            modeSelector
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var zoomSelector: some View {
        HStack(spacing: 12) {
            ForEach(ZoomLevel.allCases) { level in
                Button {
                    viewModel.selectZoom(level)
                } label: {
                    Text(level.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(viewModel.selectedZoom == level ? .yellow : .white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(viewModel.selectedZoom == level ? Color.black.opacity(0.7) : Color.black.opacity(0.35))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var galleryButton: some View {
        Button {
            viewModel.openGallery()
        } label: {
            Group {
                if let image = viewModel.lastCapturedImage {
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
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
            }
            .scaleEffect(viewModel.galleryPulseScale)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Gallery")
    }

    private var pauseButton: some View {
        Button {
            viewModel.toggleRecordingPause()
        } label: {
            Image(systemName: viewModel.isRecordingPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.isRecordingPaused ? "Resume Recording" : "Pause Recording")
    }

    private var shutterButton: some View {
        Button {
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
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    private var modeSelector: some View {
        HStack(spacing: 24) {
            ForEach(CaptureMode.allCases) { mode in
                Button {
                    viewModel.captureMode = mode
                    if mode == .photo, viewModel.isRecording {
                        viewModel.handleShutter()
                    }
                } label: {
                    Text(mode.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.captureMode == mode ? .yellow : .white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
