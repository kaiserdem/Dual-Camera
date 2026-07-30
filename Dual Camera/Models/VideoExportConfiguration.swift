//
//  VideoExportConfiguration.swift
//  Dual Camera
//

import AVFoundation
import CoreGraphics

struct VideoExportConfiguration: Sendable {
    var codec: VideoCodecOption
    var container: VideoContainerOption
    var resolution: VideoResolutionOption

    static let `default` = VideoExportConfiguration(
        codec: .hevc,
        container: .mov,
        resolution: .p1080
    )

    nonisolated var fileType: AVFileType {
        switch container {
        case .mov: .mov
        case .mp4: .mp4
        }
    }

    nonisolated var pathExtension: String { container.pathExtension }

    nonisolated var maxLongEdge: CGFloat { resolution.maxLongEdge }

    nonisolated var preferredAVCodec: AVVideoCodecType {
        switch codec {
        case .hevc: .hevc
        case .h264: .h264
        }
    }
}
