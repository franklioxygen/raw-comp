import CoreGraphics
import CoreImage
import Foundation

enum HueMaskTarget: Sendable {
    case colorBand(ColorBandID)
    case toneChannel(ToneCurveChannel)
}

enum HueMaskGenerator {
    private static let maskDimension = 256

    static func maskImage(for source: CIImage, target: HueMaskTarget, context: CIContext) -> CIImage? {
        guard let cgImage = renderSample(cgImageFrom: source, context: context) else {
            return nil
        }

        let maskCGImage: CGImage?
        switch target {
        case let .colorBand(band):
            maskCGImage = makeHueBandMask(cgImage: cgImage, band: band)
        case let .toneChannel(channel):
            maskCGImage = makeRGBChannelMask(cgImage: cgImage, channel: channel)
        }

        guard let maskCGImage else {
            return nil
        }

        let extent = source.extent.integral
        let scaleX = extent.width / CGFloat(maskDimension)
        let scaleY = extent.height / CGFloat(maskDimension)
        return CIImage(cgImage: maskCGImage)
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: extent)
    }

    private static func renderSample(cgImageFrom image: CIImage, context: CIContext) -> CGImage? {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else {
            return nil
        }

        let longest = max(extent.width, extent.height)
        let scale = CGFloat(maskDimension) / longest
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledExtent = scaled.extent.integral

        return context.createCGImage(
            scaled,
            from: scaledExtent,
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
    }

    private static func makeHueBandMask(cgImage: CGImage, band: ColorBandID) -> CGImage? {
        guard let pixels = rgbaPixels(from: cgImage) else {
            return nil
        }

        let center = band.centerHueDegrees
        let width = band.hueWidthDegrees
        var mask = [UInt8](repeating: 0, count: maskDimension * maskDimension)

        for index in 0..<mask.count {
            let offset = index * 4
            let red = Double(pixels[offset]) / 255
            let green = Double(pixels[offset + 1]) / 255
            let blue = Double(pixels[offset + 2]) / 255
            let weight = hueBandWeight(red: red, green: green, blue: blue, center: center, width: width)
            mask[index] = UInt8(min(max(weight * 255, 0), 255))
        }

        return grayscaleImage(from: mask, width: maskDimension, height: maskDimension)
    }

    private static func makeRGBChannelMask(cgImage: CGImage, channel: ToneCurveChannel) -> CGImage? {
        guard channel != .master, let pixels = rgbaPixels(from: cgImage) else {
            return nil
        }

        var mask = [UInt8](repeating: 0, count: maskDimension * maskDimension)

        for index in 0..<(pixels.count / 4) {
            let offset = index * 4
            let red = Double(pixels[offset]) / 255
            let green = Double(pixels[offset + 1]) / 255
            let blue = Double(pixels[offset + 2]) / 255
            let weight = rgbChannelWeight(red: red, green: green, blue: blue, channel: channel)
            mask[index] = UInt8(min(max(weight * 255, 0), 255))
        }

        return grayscaleImage(from: mask, width: maskDimension, height: maskDimension)
    }

    private static func hueBandWeight(
        red: Double,
        green: Double,
        blue: Double,
        center: Double,
        width: Double
    ) -> Double {
        let maxC = max(red, green, blue)
        let minC = min(red, green, blue)
        let delta = maxC - minC
        guard delta > 0.01, maxC > 0.01 else {
            return 0
        }

        var hue: Double
        if maxC == red {
            hue = (green - blue) / delta
        } else if maxC == green {
            hue = 2 + ((blue - red) / delta)
        } else {
            hue = 4 + ((red - green) / delta)
        }
        hue = (hue * 60).truncatingRemainder(dividingBy: 360)
        if hue < 0 {
            hue += 360
        }

        var deltaHue = abs(hue - center)
        deltaHue = min(deltaHue, 360 - deltaHue)
        let softness = max(width * 0.35, 4)
        let ramp = max(0, min(1, (width - deltaHue) / max(width - softness, 0.001)))
        return ramp * min(1, delta / maxC)
    }

    private static func rgbChannelWeight(
        red: Double,
        green: Double,
        blue: Double,
        channel: ToneCurveChannel
    ) -> Double {
        switch channel {
        case .master:
            return 1
        case .red:
            return max(0, red - max(green, blue)) / max(red, 0.001)
        case .green:
            return max(0, green - max(red, blue)) / max(green, 0.001)
        case .blue:
            return max(0, blue - max(red, green)) / max(blue, 0.001)
        }
    }

    private static func rgbaPixels(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        guard width == maskDimension, height == maskDimension else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard
            let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private static func grayscaleImage(from mask: [UInt8], width: Int, height: Int) -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for index in 0..<mask.count {
            let value = mask[index]
            let offset = index * 4
            pixels[offset] = value
            pixels[offset + 1] = value
            pixels[offset + 2] = value
            pixels[offset + 3] = 255
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )?.makeImage()
    }
}
