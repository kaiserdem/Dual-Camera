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

    static func defaultPiPCenter(
        in size: CGSize,
        shape: PiPShape = .square,
        scale: CGFloat = 0.28
    ) -> CGPoint {
        let pipWidth = size.width * scale * shape.widthMultiplier
        let pipHeight = pipWidth * shape.heightMultiplier
        return CGPoint(
            x: size.width - pipWidth / 2 - 16,
            y: pipHeight / 2 + 16
        )
    }

    func pipRect(in outputSize: CGSize) -> CGRect {
        let source = viewfinderSize.width > 1 ? viewfinderSize : outputSize

        // Uniform scale (aspect-fill mapping) so PiP is not distorted vs viewfinder.
        let scale = max(
            outputSize.width / max(source.width, 1),
            outputSize.height / max(source.height, 1)
        )
        let offsetX = (outputSize.width - source.width * scale) / 2
        let offsetY = (outputSize.height - source.height * scale) / 2

        let pipWidth = source.width * pipScale * pipShape.widthMultiplier * scale
        let pipHeight = pipWidth * pipShape.heightMultiplier
        let center = CGPoint(
            x: offsetX + pipCenter.x * scale,
            y: offsetY + pipCenter.y * scale
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
    /// Crop/full uses the on-screen viewfinder aspect so framing matches preview
    /// (forced 9:16 was narrower and aspect-fill cropped the sides).
    func videoFrameSize(maxLongEdge: CGFloat = 1920) -> CGSize {
        let aspect: CGFloat
        switch aspectRatio {
        case .full:
            if viewfinderSize.width > 1, viewfinderSize.height > 1 {
                aspect = viewfinderSize.width / viewfinderSize.height
            } else {
                aspect = 9.0 / 16.0
            }
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

    /// Crop/full keeps the whole camera frame (no side crop). Fixed ratios may fill/crop.
    var prefersAspectFit: Bool {
        aspectRatio == .full
    }

    private static func evenEncoderSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: max(floor(size.width / 2) * 2, 2),
            height: max(floor(size.height / 2) * 2, 2)
        )
    }
}
