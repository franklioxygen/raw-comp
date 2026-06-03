import CoreGraphics
import Foundation

struct ImageHistogram: Equatable, Sendable {
    var red: [Int] = Array(repeating: 0, count: 256)
    var green: [Int] = Array(repeating: 0, count: 256)
    var blue: [Int] = Array(repeating: 0, count: 256)
    var luma: [Int] = Array(repeating: 0, count: 256)
    var highlightClipCount: Int = 0
    var shadowClipCount: Int = 0
    var totalSamples: Int = 0

    var hasHighlightClipping: Bool {
        highlightClipCount > 0
    }

    var hasShadowClipping: Bool {
        shadowClipCount > 0
    }
}

enum HistogramComputer {
    static func compute(from cgImage: CGImage, maxSampleDimension: Int = 512) -> ImageHistogram {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            return ImageHistogram()
        }

        let scale = min(1, Double(maxSampleDimension) / Double(max(width, height)))
        let sampleWidth = max(1, Int(Double(width) * scale))
        let sampleHeight = max(1, Int(Double(height) * scale))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var data = [UInt8](repeating: 0, count: sampleHeight * bytesPerRow)

        guard
            let context = CGContext(
                data: &data,
                width: sampleWidth,
                height: sampleHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else {
            return ImageHistogram()
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var histogram = ImageHistogram()
        let pixelCount = sampleWidth * sampleHeight
        histogram.totalSamples = pixelCount

        for index in 0..<pixelCount {
            let offset = index * bytesPerPixel
            let red = Int(data[offset])
            let green = Int(data[offset + 1])
            let blue = Int(data[offset + 2])
            let luma = Int(
                0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
            )

            histogram.red[red] += 1
            histogram.green[green] += 1
            histogram.blue[blue] += 1
            histogram.luma[luma] += 1

            if red >= 252 || green >= 252 || blue >= 252 {
                histogram.highlightClipCount += 1
            }
            if red <= 3 && green <= 3 && blue <= 3 {
                histogram.shadowClipCount += 1
            }
        }

        return histogram
    }
}
