import CoreGraphics
import Foundation

enum WorkingColorSpace {
    /// Normalizes decoded rasters to sRGB for a consistent adjustment working space.
    static func sRGBCGImage(from image: CGImage) -> CGImage {
        guard let imageSpace = image.colorSpace else {
            return image
        }

        let sRGBVariants: Set<CFString> = [
            CGColorSpace.sRGB,
            CGColorSpace.linearSRGB,
            CGColorSpace.extendedSRGB,
            CGColorSpace.extendedLinearSRGB,
        ]
        if let name = imageSpace.name, sRGBVariants.contains(name) {
            return image
        }

        guard
            let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: sRGB,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage() ?? image
    }
}
