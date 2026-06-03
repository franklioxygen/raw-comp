import CoreGraphics
import Foundation

enum PixelSampler {
    static func sample(
        cgImage: CGImage,
        normalizedPoint: CGPoint,
        sampleSize: PixelSampleSize
    ) -> PixelReadout {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            return .empty
        }

        let centerX = Int((normalizedPoint.x.clamped01 * Double(width - 1)).rounded())
        let centerY = Int(((1 - normalizedPoint.y.clamped01) * Double(height - 1)).rounded())
        let radius = sampleSize.rawValue / 2

        let cropMinX = max(0, centerX - radius)
        let cropMinY = max(0, centerY - radius)
        let cropMaxX = min(width - 1, centerX + radius)
        let cropMaxY = min(height - 1, centerY + radius)
        guard cropMaxX >= cropMinX, cropMaxY >= cropMinY else {
            return .empty
        }

        let cropRect = CGRect(x: cropMinX, y: cropMinY, width: cropMaxX - cropMinX + 1, height: cropMaxY - cropMinY + 1)
        guard let tile = cgImage.cropping(to: cropRect) else {
            return .empty
        }

        let tileWidth = tile.width
        let tileHeight = tile.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = tileWidth * bytesPerPixel
        var data = [UInt8](repeating: 0, count: tileHeight * bytesPerRow)

        guard
            let context = CGContext(
                data: &data,
                width: tileWidth,
                height: tileHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else {
            return .empty
        }

        context.draw(tile, in: CGRect(x: 0, y: 0, width: tileWidth, height: tileHeight))

        var redTotal = 0
        var greenTotal = 0
        var blueTotal = 0
        var count = 0

        for pixelIndex in 0..<(tileWidth * tileHeight) {
            let offset = pixelIndex * bytesPerPixel
            redTotal += Int(data[offset])
            greenTotal += Int(data[offset + 1])
            blueTotal += Int(data[offset + 2])
            count += 1
        }

        guard count > 0 else {
            return .empty
        }

        let red = redTotal / count
        let green = greenTotal / count
        let blue = blueTotal / count
        let luma = Int(0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue))

        return PixelReadout(
            normalizedX: normalizedPoint.x.clamped01,
            normalizedY: normalizedPoint.y.clamped01,
            red: red,
            green: green,
            blue: blue,
            luma: luma
        )
    }
}

private extension Double {
    var clamped01: Double {
        Swift.min(Swift.max(self, 0), 1)
    }
}

private extension CGFloat {
    var clamped01: CGFloat {
        Swift.min(Swift.max(self, 0), 1)
    }
}

private extension CGPoint {
    var clamped01: CGPoint {
        CGPoint(x: x.clamped01, y: y.clamped01)
    }
}
