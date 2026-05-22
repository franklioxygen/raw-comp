import CoreGraphics
@preconcurrency import CoreImage
import Foundation

actor ImageAdjustmentRenderer {
    static let shared = ImageAdjustmentRenderer()

    private let context = CIContext()
    private let fallbackColorSpace = CGColorSpace(name: CGColorSpace.sRGB)

    func render(_ loadedImage: LoadedImage, adjustments: ComparisonAdjustments) -> CGImage? {
        guard !adjustments.isNeutral else {
            return loadedImage.cgImage
        }

        var image = CIImage(cgImage: loadedImage.cgImage)

        if adjustments.exposureEV != 0 {
            guard let filter = CIFilter(name: "CIExposureAdjust") else {
                return loadedImage.cgImage
            }

            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(adjustments.exposureEV, forKey: kCIInputEVKey)
            if let output = filter.outputImage {
                image = output
            }
        }

        if adjustments.brightness != 0 || adjustments.contrast != 1 || adjustments.saturation != 1 {
            guard let filter = CIFilter(name: "CIColorControls") else {
                return loadedImage.cgImage
            }

            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(adjustments.brightness, forKey: kCIInputBrightnessKey)
            filter.setValue(adjustments.contrast, forKey: kCIInputContrastKey)
            filter.setValue(adjustments.saturation, forKey: kCIInputSaturationKey)
            if let output = filter.outputImage {
                image = output
            }
        }

        if adjustments.sharpness > 0 {
            guard let filter = CIFilter(name: "CISharpenLuminance") else {
                return loadedImage.cgImage
            }

            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(adjustments.sharpness, forKey: kCIInputSharpnessKey)
            filter.setValue(1.6, forKey: kCIInputRadiusKey)
            if let output = filter.outputImage {
                image = output
            }
        }

        let extent = image.extent.integral
        let colorSpace = loadedImage.cgImage.colorSpace ?? fallbackColorSpace
        return context.createCGImage(image, from: extent, format: .RGBA8, colorSpace: colorSpace)
    }
}
