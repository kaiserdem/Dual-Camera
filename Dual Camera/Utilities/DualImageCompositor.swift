//
//  DualImageCompositor.swift
//  Dual Camera
//

import UIKit
import ImageIO
import UniformTypeIdentifiers

enum DualImageCompositor {
    static func compose(
        primary: UIImage,
        secondary: UIImage,
        context: CaptureLayoutContext
    ) -> UIImage {
        let primaryImage = primary.normalizedOrientation()
        let secondaryImage = secondary.normalizedOrientation()
        let outputSize = outputSize(for: primaryImage.size, context: context)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard

        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.interpolationQuality = .high
            let bounds = CGRect(origin: .zero, size: outputSize)

            switch context.layout {
            case .pip:
                draw(primaryImage, in: bounds, fill: !context.prefersAspectFit)
                let pipRect = context.pipRect(in: outputSize)
                drawPiP(secondaryImage, in: pipRect, context: context, cg: cg)

            case .verticalSplit:
                let ratio = context.verticalSplitRatio
                let left = CGRect(x: 0, y: 0, width: outputSize.width * ratio, height: outputSize.height)
                let right = CGRect(
                    x: left.maxX,
                    y: 0,
                    width: outputSize.width - left.width,
                    height: outputSize.height
                )
                draw(primaryImage, in: left, fill: !context.prefersAspectFit)
                draw(secondaryImage, in: right, fill: !context.prefersAspectFit)
                drawSeparator(
                    from: CGPoint(x: left.maxX, y: 0),
                    to: CGPoint(x: left.maxX, y: outputSize.height),
                    context: context,
                    outputSize: outputSize,
                    cg: cg
                )

            case .horizontalSplit:
                let ratio = context.horizontalSplitRatio
                let top = CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height * ratio)
                let bottom = CGRect(
                    x: 0,
                    y: top.maxY,
                    width: outputSize.width,
                    height: outputSize.height - top.height
                )
                draw(primaryImage, in: top, fill: !context.prefersAspectFit)
                draw(secondaryImage, in: bottom, fill: !context.prefersAspectFit)
                drawSeparator(
                    from: CGPoint(x: 0, y: top.maxY),
                    to: CGPoint(x: outputSize.width, y: top.maxY),
                    context: context,
                    outputSize: outputSize,
                    cg: cg
                )
            }
        }
    }

    static func compose(
        primaryBuffer: CVPixelBuffer,
        secondaryBuffer: CVPixelBuffer,
        context: CaptureLayoutContext
    ) -> UIImage? {
        let primary = UIImage(pixelBuffer: primaryBuffer)
        let secondary = UIImage(pixelBuffer: secondaryBuffer)
        guard let primary, let secondary else { return nil }
        return compose(primary: primary, secondary: secondary, context: context)
    }

    // MARK: - Private

    /// Fit follows the on-screen viewfinder aspect (same rule as `videoFrameSize`)
    /// so PiP lands where the preview shows it instead of drifting in the sensor frame.
    private static func outputSize(for imageSize: CGSize, context: CaptureLayoutContext) -> CGSize {
        let ratio: CGFloat
        if let fixed = context.aspectRatio.ratio {
            ratio = fixed
        } else {
            let viewfinder = context.viewfinderSize
            guard viewfinder.width > 1, viewfinder.height > 1 else { return imageSize }
            ratio = viewfinder.width / viewfinder.height
        }

        let imageRatio = imageSize.width / max(imageSize.height, 1)
        if imageRatio > ratio {
            let height = imageSize.height
            return CGSize(width: height * ratio, height: height)
        } else {
            let width = imageSize.width
            return CGSize(width: width, height: width / ratio)
        }
    }

    /// Aspect-fill/fit without stretching.
    private static func draw(_ image: UIImage, in rect: CGRect, fill: Bool) {
        let imageSize = image.size
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

        guard let cg = UIGraphicsGetCurrentContext() else {
            image.draw(in: drawRect)
            return
        }

        cg.saveGState()
        cg.clip(to: rect)
        image.draw(in: drawRect)
        cg.restoreGState()
    }

    private static func drawAspectFill(_ image: UIImage, in rect: CGRect) {
        draw(image, in: rect, fill: true)
    }

    private static func drawPiP(
        _ image: UIImage,
        in rect: CGRect,
        context: CaptureLayoutContext,
        cg: CGContext
    ) {
        cg.saveGState()
        let path = pipPath(in: rect, context: context)
        cg.addPath(path)
        cg.clip()
        drawAspectFill(image, in: rect)
        cg.restoreGState()

        guard context.isBorderEnabled else { return }
        let mappedLineWidth = max(
            context.borderWidth * (rect.width / max(context.viewfinderSize.width * context.pipScale, 1)),
            1
        )

        cg.saveGState()
        cg.setStrokeColor(context.borderColor.cgColor)
        cg.setLineWidth(mappedLineWidth)
        if context.borderLineStyle == .dashed {
            cg.setLineDash(phase: 0, lengths: [mappedLineWidth * 3, mappedLineWidth * 2])
        } else {
            cg.setLineDash(phase: 0, lengths: [])
        }
        cg.addPath(pipPath(in: rect.insetBy(dx: mappedLineWidth / 2, dy: mappedLineWidth / 2), context: context))
        cg.strokePath()
        cg.restoreGState()
    }

    private static func pipPath(in rect: CGRect, context: CaptureLayoutContext) -> CGPath {
        switch context.pipShape {
        case .circle:
            return UIBezierPath(ovalIn: rect).cgPath
        case .square, .rectangle:
            if context.isPiPRounded {
                return UIBezierPath(
                    roundedRect: rect,
                    cornerRadius: min(rect.width, rect.height) * 0.12
                ).cgPath
            }
            return UIBezierPath(rect: rect).cgPath
        }
    }

    private static func drawSeparator(
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
        } else {
            cg.setLineDash(phase: 0, lengths: [])
        }
        cg.move(to: from)
        cg.addLine(to: to)
        cg.strokePath()
        cg.restoreGState()
    }
}

extension UIImage {
    /// Bake orientation into pixel data so size/aspect math stays consistent.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let pixelSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: pixelSize))
        }
    }

    @discardableResult
    func writeHEIC(to url: URL, compressionQuality: CGFloat) -> Bool {
        guard let cgImage else { return false }
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.heic.identifier as CFString, 1, nil)
        guard let destination else { return false }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    @discardableResult
    func writeJPEG(to url: URL, compressionQuality: CGFloat) -> Bool {
        guard let data = jpegData(compressionQuality: compressionQuality) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    convenience init?(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        self.init(cgImage: cgImage, scale: 1, orientation: .up)
    }

    /// Writes into `targetSize` using aspect-fill (crop), never stretch.
    func pixelBufferAspectFilled(size targetSize: CGSize) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(targetSize.width),
            Int(targetSize.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }

        ctx.translateBy(x: 0, y: targetSize.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.clear(CGRect(origin: .zero, size: targetSize))

        let imageSize = size
        let scale = max(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(
            x: (targetSize.width - drawSize.width) / 2,
            y: (targetSize.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        UIGraphicsPushContext(ctx)
        draw(in: drawRect)
        UIGraphicsPopContext()
        return buffer
    }
}
