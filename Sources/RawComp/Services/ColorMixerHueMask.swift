import CoreImage
import Foundation

enum ColorMixerHueMask {
    static func maskImage(for source: CIImage, band: ColorBandID, context: CIContext) -> CIImage? {
        HueMaskGenerator.maskImage(for: source, target: .colorBand(band), context: context)
    }

    static func blend(original: CIImage, adjusted: CIImage, mask: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            return adjusted
        }

        filter.setValue(adjusted, forKey: kCIInputImageKey)
        filter.setValue(original, forKey: kCIInputBackgroundImageKey)
        filter.setValue(mask, forKey: kCIInputMaskImageKey)
        return filter.outputImage ?? adjusted
    }
}
