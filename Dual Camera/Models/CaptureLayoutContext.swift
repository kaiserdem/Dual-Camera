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
        let pipWidth = size.width * scale
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

        let pipWidth = source.width * pipScale * scale
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
}
