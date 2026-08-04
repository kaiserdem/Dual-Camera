//
//  CaptureLayoutContext.swift
//  Dual Camera
//

import CoreGraphics
import UIKit

struct CaptureLayoutContext: @unchecked Sendable {
    var layout: CameraLayout
    var pipShape: PiPShape
    var isPiPRounded: Bool
    var pipScale: CGFloat
    var isBorderEnabled: Bool
    var borderWidth: CGFloat
    var borderColor: UIColor
    var borderLineStyle: BorderLineStyle
    var verticalSplitRatio: CGFloat
    var horizontalSplitRatio: CGFloat
    var aspectRatio: AspectRatio
    var viewfinderSize: CGSize
    /// PiP center in viewfinder coordinates.
    var pipCenter: CGPoint

    static let pipEdgeInset: CGFloat = 16

    static func defaultPiPCenter(
        in size: CGSize,
        shape: PiPShape = .square,
        scale: CGFloat = 0.28
    ) -> CGPoint {
        let pipWidth = size.width * scale * shape.widthMultiplier
        let pipHeight = pipWidth * shape.heightMultiplier
        let inset = pipEdgeInset
        return CGPoint(
            x: size.width - pipWidth / 2 - inset,
            y: pipHeight / 2 + inset
        )
    }

    /// Maps on-screen PiP into the encoder frame.
    /// Uses independent X/Y scales so the 16pt edge insets stay correct when
    /// Fit export aspect (device screen) differs from the chrome-inset viewfinder.
    func pipRect(in outputSize: CGSize) -> CGRect {
        let source = viewfinderSize.width > 1 ? viewfinderSize : outputSize
        let scaleX = outputSize.width / max(source.width, 1)
        let scaleY = outputSize.height / max(source.height, 1)

        let pipWidth = source.width * pipScale * pipShape.widthMultiplier * scaleX
        let pipHeight = pipWidth * pipShape.heightMultiplier
        let center = CGPoint(
            x: pipCenter.x * scaleX,
            y: pipCenter.y * scaleY
        )

        return CGRect(
            x: center.x - pipWidth / 2,
            y: center.y - pipHeight / 2,
            width: pipWidth,
            height: pipHeight
        )
    }

    func scaledBorderWidth(for outputSize: CGSize) -> CGFloat {
        let source = viewfinderSize.width > 1 ? viewfinderSize.width : outputSize.width
        let scale = outputSize.width / max(source, 1)
        return max(borderWidth * scale, 1)
    }

    /// Encoder frame size matching the selected ratio.
    /// Fit uses the **device screen** aspect (not the chrome-inset viewfinder): exporting the
    /// shorter stage made a wider file that fullscreen players side-crop, eating PiP's right inset.
    /// Full uses portrait 9:16 like the stock Camera app.
    func videoFrameSize(maxLongEdge: CGFloat = 1920) -> CGSize {
        let aspect: CGFloat
        switch aspectRatio {
        case .full:
            aspect = Self.fitExportAspect(viewfinderSize: viewfinderSize)
        case .fill:
            aspect = 9.0 / 16.0
        case .square, .fourThree, .sixteenNine:
            if let ratio = aspectRatio.ratio {
                aspect = ratio
            } else if viewfinderSize.width > 1, viewfinderSize.height > 1 {
                aspect = viewfinderSize.width / viewfinderSize.height
            } else {
                aspect = 9.0 / 16.0
            }
        }

        let raw: CGSize
        if aspect >= 1 {
            let width = maxLongEdge
            raw = CGSize(width: width, height: width / aspect)
        } else {
            let height = maxLongEdge
            raw = CGSize(width: height * aspect, height: height)
        }

        return Self.evenEncoderSize(raw)
    }

    /// Portrait width/height of the device display — matches typical fullscreen playback.
    private static func fitExportAspect(viewfinderSize: CGSize) -> CGFloat {
        let screen = UIScreen.main.bounds.size
        let portraitWidth = min(screen.width, screen.height)
        let portraitHeight = max(screen.width, screen.height)
        if portraitWidth > 1, portraitHeight > 1 {
            return portraitWidth / portraitHeight
        }
        if viewfinderSize.width > 1, viewfinderSize.height > 1 {
            return viewfinderSize.width / viewfinderSize.height
        }
        return 9.0 / 16.0
    }

    /// Fit / fixed ratios fill the frame. Only Full may letterbox on the sides.
    var prefersAspectFit: Bool {
        false
    }

    private static func evenEncoderSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: max(floor(size.width / 2) * 2, 2),
            height: max(floor(size.height / 2) * 2, 2)
        )
    }
}
