import AppKit
import CoreGraphics
import Foundation

enum ComparisonExportViewportRenderer {
    static func renderVisibleImage(_ image: CGImage, viewport: ViewportState) -> CGImage? {
        let rotatedImage = rasterizedImage(image, rotationQuarterTurns: viewport.rotationQuarterTurns) ?? image
        let visibleRect = viewport.visibleRectNormalized.clampedUnit()

        guard visibleRect.width > 0, visibleRect.height > 0 else {
            return rotatedImage
        }

        let cropRect = CGRect(
            x: visibleRect.minX * CGFloat(rotatedImage.width),
            y: (1 - visibleRect.maxY) * CGFloat(rotatedImage.height),
            width: visibleRect.width * CGFloat(rotatedImage.width),
            height: visibleRect.height * CGFloat(rotatedImage.height)
        ).integral.intersection(CGRect(x: 0, y: 0, width: rotatedImage.width, height: rotatedImage.height))

        guard cropRect.width > 0, cropRect.height > 0 else {
            return rotatedImage
        }

        return rotatedImage.cropping(to: cropRect) ?? rotatedImage
    }

    private static func rasterizedImage(_ image: CGImage, rotationQuarterTurns: Int) -> CGImage? {
        let normalizedTurns = ((rotationQuarterTurns % 4) + 4) % 4
        guard normalizedTurns != 0 else {
            return image
        }

        let canvasSize = normalizedTurns.isMultiple(of: 2)
            ? CGSize(width: image.width, height: image.height)
            : CGSize(width: image.height, height: image.width)

        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(canvasSize.width),
                pixelsHigh: Int(canvasSize.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            return nil
        }

        let drawRect = NSRect(
            x: -CGFloat(image.width) / 2,
            y: -CGFloat(image.height) / 2,
            width: CGFloat(image.width),
            height: CGFloat(image.height)
        )

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high

        NSColor.black.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: canvasSize))

        let transform = NSAffineTransform()
        transform.translateX(by: canvasSize.width / 2, yBy: canvasSize.height / 2)
        transform.rotate(byDegrees: CGFloat(rotationQuarterTurns * 90))
        transform.concat()

        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        nsImage.draw(
            in: drawRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )

        NSGraphicsContext.restoreGraphicsState()
        return bitmap.cgImage
    }
}
