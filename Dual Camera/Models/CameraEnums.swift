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
    case full
    case square
    case fourThree
    case sixteenNine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: "Crop"
        case .square: "1:1"
        case .fourThree: "4:3"
        case .sixteenNine: "16:9"
        }
    }

    var ratio: CGFloat? {
        switch self {
        case .full: nil
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pip: "PiP"
        case .verticalSplit: "Vertical"
        case .horizontalSplit: "Horizontal"
        }
    }

    var systemImage: String {
        switch self {
        case .pip: "rectangle.on.rectangle"
        case .verticalSplit: "rectangle.split.2x1"
        case .horizontalSplit: "rectangle.split.1x2"
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

    /// Portrait aspect for rectangle; square/circle stay 1:1.
    var heightMultiplier: CGFloat {
        switch self {
        case .square, .circle: 1
        case .rectangle: 1.25
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
