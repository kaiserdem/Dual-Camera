//
//  CameraEnums.swift
//  Dual Camera
//

import SwiftUI

enum CaptureMode: String, CaseIterable, Identifiable {
    case photo
    case video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: "Photo"
        case .video: "Video"
        }
    }
}

enum AspectRatio: String, CaseIterable, Identifiable {
    /// Edge-to-edge stage using the device viewfinder aspect (aspect-fill).
    case full
    /// Stock-camera style: portrait 9:16 frame (may letterbox on the sides).
    case fill
    case square
    case fourThree
    case sixteenNine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: "Fit"
        case .fill: "Full"
        case .square: "1:1"
        case .fourThree: "4:3"
        case .sixteenNine: "16:9"
        }
    }

    /// Width / height for framed modes. `nil` = Fit (whole stage).
    var ratio: CGFloat? {
        switch self {
        case .full: nil
        case .fill: 9.0 / 16.0
        case .square: 1
        case .fourThree: 4.0 / 3.0
        case .sixteenNine: 16.0 / 9.0
        }
    }
}

enum CameraLayout: String, CaseIterable, Identifiable {
    case pip
    case verticalSplit
    case horizontalSplit
    /// Full-frame rear (back) camera only.
    case backOnly
    /// Full-frame front camera only.
    case frontOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pip: "PiP"
        case .verticalSplit: "Vertical"
        case .horizontalSplit: "Horizontal"
        case .backOnly: "Main"
        case .frontOnly: "Front"
        }
    }

    var systemImage: String {
        switch self {
        case .pip: "rectangle.on.rectangle"
        case .verticalSplit: "rectangle.split.2x1"
        case .horizontalSplit: "rectangle.split.1x2"
        case .backOnly: "camera.fill"
        case .frontOnly: "person.crop.circle"
        }
    }

    /// Solo layouts compose a single camera into the full output frame.
    var usesSingleCamera: Bool {
        switch self {
        case .backOnly, .frontOnly: true
        case .pip, .verticalSplit, .horizontalSplit: false
        }
    }
}

enum PiPShape: String, CaseIterable, Identifiable {
    case square
    case rectangle
    case circle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: "Square"
        case .rectangle: "Rectangle"
        case .circle: "Circle"
        }
    }

    /// Width relative to the base PiP scale (square/circle = 1).
    var widthMultiplier: CGFloat {
        switch self {
        case .square, .circle: 1
        case .rectangle: 0.78
        }
    }

    /// Height / width of the PiP frame. Rectangle is a taller portrait.
    var heightMultiplier: CGFloat {
        switch self {
        case .square, .circle: 1
        case .rectangle: 1.55
        }
    }

    var supportsRoundedCorners: Bool {
        self != .circle
    }
}

enum BorderStyle: String, CaseIterable, Identifiable {
    case cyan
    case black
    case white

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cyan: "Cyan"
        case .black: "Black"
        case .white: "White"
        }
    }

    var color: Color {
        switch self {
        case .cyan: Color(.sRGB, red: 0, green: 1, blue: 1, opacity: 1)
        case .black: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
        case .white: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)
        }
    }

    var hexValue: String {
        switch self {
        case .cyan: "#00FFFFFF"
        case .black: "#000000FF"
        case .white: "#FFFFFFFF"
        }
    }
}

enum BorderLineStyle: String, CaseIterable, Identifiable {
    case dashed
    case solid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashed: "Dashed"
        case .solid: "Solid"
        }
    }

    var systemImage: String {
        switch self {
        case .dashed: "rectangle.dashed"
        case .solid: "rectangle"
        }
    }
}

enum ActiveOverlay: String, CaseIterable, Identifiable {
    case none
    case ratio
    case layout
    case more

    var id: String { rawValue }
}

enum ZoomLevel: String, CaseIterable, Identifiable {
    case half
    case one
    case two

    var id: String { rawValue }

    var title: String {
        switch self {
        case .half: "0.5"
        case .one: "1x"
        case .two: "2"
        }
    }

    var factor: CGFloat {
        switch self {
        case .half: 0.5
        case .one: 1.0
        case .two: 2.0
        }
    }
}

enum FlashModeOption: String, CaseIterable, Identifiable {
    case off
    case on
    case auto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .on: "On"
        case .auto: "Auto"
        }
    }

    var systemImage: String {
        switch self {
        case .off: "bolt.slash.fill"
        case .on: "bolt.fill"
        case .auto: "bolt.badge.automatic.fill"
        }
    }
}

enum VideoCodecOption: String, CaseIterable, Identifiable, Sendable {
    case hevc
    case h264

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hevc: "High Efficiency"
        case .h264: "Most Compatible"
        }
    }

    var subtitle: String {
        switch self {
        case .hevc: "HEVC"
        case .h264: "H.264"
        }
    }
}

enum VideoContainerOption: String, CaseIterable, Identifiable, Sendable {
    case mov
    case mp4

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mov: "MOV"
        case .mp4: "MP4"
        }
    }

    nonisolated var pathExtension: String { rawValue }
}

enum VideoResolutionOption: String, CaseIterable, Identifiable, Sendable {
    case p720
    case p1080

    var id: String { rawValue }

    var title: String {
        switch self {
        case .p720: "720p"
        case .p1080: "1080p"
        }
    }

    /// Long edge passed to `CaptureLayoutContext.videoFrameSize`.
    nonisolated var maxLongEdge: CGFloat {
        switch self {
        case .p720: 1280
        case .p1080: 1920
        }
    }
}
