import CoreGraphics
import CoreImage
import Foundation

enum FalseColorLUT {
    /// Builds a 256×1 RGBA gradient for `CIColorMap` (shadows → highlights).
    static func gradientImage() -> CIImage? {
        let width = 256
        let height = 1
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for index in 0..<width {
            let t = Double(index) / Double(width - 1)
            let (red, green, blue) = paletteComponents(at: t)
            let offset = index * 4
            pixels[offset] = UInt8(min(max(red * 255, 0), 255))
            pixels[offset + 1] = UInt8(min(max(green * 255, 0), 255))
            pixels[offset + 2] = UInt8(min(max(blue * 255, 0), 255))
            pixels[offset + 3] = 255
        }

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let provider = CGDataProvider(data: Data(pixels) as CFData),
            let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        else {
            return nil
        }

        return CIImage(cgImage: cgImage)
    }

    private static func paletteComponents(at t: Double) -> (Double, Double, Double) {
        let stops: [(Double, Double, Double, Double)] = [
            (0.0, 0.05, 0.05, 0.55),
            (0.2, 0.1, 0.45, 0.95),
            (0.4, 0.15, 0.85, 0.55),
            (0.55, 0.2, 0.9, 0.25),
            (0.7, 0.95, 0.85, 0.1),
            (0.85, 1.0, 0.45, 0.05),
            (1.0, 0.95, 0.1, 0.05)
        ]

        let firstStop = stops[0]
        if t <= firstStop.0 {
            return (firstStop.1, firstStop.2, firstStop.3)
        }

        for index in 1..<stops.count {
            let stop = stops[index]
            let previous = stops[index - 1]
            if t <= stop.0 {
                let span = stop.0 - previous.0
                let local = span > 0 ? (t - previous.0) / span : 0
                return (
                    previous.1 + ((stop.1 - previous.1) * local),
                    previous.2 + ((stop.2 - previous.2) * local),
                    previous.3 + ((stop.3 - previous.3) * local)
                )
            }
        }

        let last = stops[stops.count - 1]
        return (last.1, last.2, last.3)
    }
}
