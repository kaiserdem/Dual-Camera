//
//  DualFrameCompositor.swift
//  Dual Camera
//

import AVFoundation
import CoreImage
import UIKit

nonisolated enum DualFrameCompositor {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    nonisolated static func compose(
        primary: CVPixelBuffer,
        secondary: CVPixelBuffer,
        context: CaptureLayoutContext,
        outputSize: CGSize
    ) -> CVPixelBuffer? {
        guard let output = makeBuffer(width: Int(outputSize.width), height: Int(outputSize.height)) else {
            return nil
        }

        let primaryImage = CIImage(cvPixelBuffer: primary)
        let secondaryImage = CIImage(cvPixelBuffer: secondary)

        CVPixelBufferLockBaseAddress(output, [])
        defer { CVPixelBufferUnlockBaseAddress(output, []) }

        guard let cg = CGContext(
            data: CVPixelBufferGetBaseAddress(output),
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(output),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }

        // CVPixelBuffer is flipped vs UIKit; draw in buffer space (origin bottom-left).
        cg.clear(CGRect(origin: .zero, size: outputSize))
        cg.interpolationQuality = .high

        let bounds = CGRect(origin: .zero, size: outputSize)
        let fillCamera = !context.prefersAspectFit

        switch context.layout {
        case .pip:
            draw(primaryImage, in: bounds, cg: cg, fill: fillCamera)
            let pip = context.pipRect(in: outputSize)
            let flippedPip = flipRect(pip, in: outputSize)
            cg.saveGState()
            cg.addPath(pipPath(in: flippedPip, context: context))
            cg.clip()
            draw(secondaryImage, in: flippedPip, cg: cg, fill: true)
            cg.restoreGState()
            if context.isBorderEnabled {
                strokePiP(in: flippedPip, context: context, cg: cg)
            }

        case .verticalSplit:
            let ratio = context.verticalSplitRatio
            let left = CGRect(x: 0, y: 0, width: outputSize.width * ratio, height: outputSize.height)
            let right = CGRect(x: left.maxX, y: 0, width: outputSize.width - left.width, height: outputSize.height)
            draw(primaryImage, in: left, cg: cg, fill: fillCamera)
            draw(secondaryImage, in: right, cg: cg, fill: fillCamera)
            strokeSeparator(
                from: CGPoint(x: left.maxX, y: 0),
                to: CGPoint(x: left.maxX, y: outputSize.height),
                context: context,
                outputSize: outputSize,
                cg: cg
            )

        case .horizontalSplit:
            let ratio = context.horizontalSplitRatio
            // In buffer coords y goes up; "top" of UI is high y.
            let topHeight = outputSize.height * ratio
            let top = CGRect(x: 0, y: outputSize.height - topHeight, width: outputSize.width, height: topHeight)
            let bottom = CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height - topHeight)
            draw(primaryImage, in: top, cg: cg, fill: fillCamera)
            draw(secondaryImage, in: bottom, cg: cg, fill: fillCamera)
            strokeSeparator(
                from: CGPoint(x: 0, y: bottom.maxY),
                to: CGPoint(x: outputSize.width, y: bottom.maxY),
                context: context,
                outputSize: outputSize,
                cg: cg
            )
        }

        return output
    }

    // MARK: - Drawing

    private static func drawAspectFill(_ image: CIImage, in rect: CGRect, cg: CGContext) {
        draw(image, in: rect, cg: cg, fill: true)
    }

    private static func drawAspectFit(_ image: CIImage, in rect: CGRect, cg: CGContext) {
        draw(image, in: rect, cg: cg, fill: false)
    }

    private static func draw(_ image: CIImage, in rect: CGRect, cg: CGContext, fill: Bool) {
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return }
        let imageSize = image.extent.size
        guard imageSize.width > 0, imageSize.height > 0, rect.width > 0, rect.height > 0 else { return }

        let scale = fill
            ? max(rect.width / imageSize.width, rect.height / imageSize.height)
            : min(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        cg.saveGState()
        cg.clip(to: rect)
        cg.draw(cgImage, in: drawRect)
        cg.restoreGState()
    }

    private static func flipRect(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: size.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    private static func pipPath(in rect: CGRect, context: CaptureLayoutContext) -> CGPath {
        switch context.pipShape {
        case .circle:
            return CGPath(ellipseIn: rect, transform: nil)
        case .square, .rectangle:
            if context.isPiPRounded {
                let radius = min(rect.width, rect.height) * 0.12
                return CGPath(
                    roundedRect: rect,
                    cornerWidth: radius,
                    cornerHeight: radius,
                    transform: nil
                )
            }
            return CGPath(rect: rect, transform: nil)
        }
    }

    private static func strokePiP(in rect: CGRect, context: CaptureLayoutContext, cg: CGContext) {
        let lineWidth = max(context.borderWidth * (rect.width / max(context.viewfinderSize.width * context.pipScale, 1)), 1)
        cg.saveGState()
        cg.setStrokeColor(context.borderColor.cgColor)
        cg.setLineWidth(lineWidth)
        if context.borderLineStyle == .dashed {
            cg.setLineDash(phase: 0, lengths: [lineWidth * 3, lineWidth * 2])
        }
        cg.addPath(pipPath(in: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2), context: context))
        cg.strokePath()
        cg.restoreGState()
    }

    private static func strokeSeparator(
        from: CGPoint,
        to: CGPoint,
        context: CaptureLayoutContext,
        outputSize: CGSize,
        cg: CGContext
    ) {
        guard context.isBorderEnabled else { return }
        let lineWidth = context.scaledBorderWidth(for: outputSize)
        cg.saveGState()
        cg.setStrokeColor(context.borderColor.cgColor)
        cg.setLineWidth(lineWidth)
        cg.setLineCap(.round)
        if context.borderLineStyle == .dashed {
            cg.setLineDash(phase: 0, lengths: [lineWidth * 4, lineWidth * 3])
        }
        cg.move(to: from)
        cg.addLine(to: to)
        cg.strokePath()
        cg.restoreGState()
    }

    private static func makeBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        return status == kCVReturnSuccess ? buffer : nil
    }
}
