import CoreGraphics
@preconcurrency import CoreImage
import Foundation

actor ImageAnalysisRenderer {
    static let shared = ImageAnalysisRenderer()

    private let context = CIContext()
    private let fallbackColorSpace = CGColorSpace(name: CGColorSpace.sRGB)

    func render(
        baseCGImage: CGImage,
        adjustments: ComparisonAdjustments,
        forceClippingOverlay: Bool = false
    ) -> CGImage? {
        var image = CIImage(cgImage: baseCGImage)

        if forceClippingOverlay {
            image = applyClippingOverlay(image)
            return export(image, colorSpace: baseCGImage.colorSpace)
        }

        if adjustments.inspector.enabledSections.contains(.presence),
           adjustments.presence.edgeMapPreview {
            image = applyEdgeMap(image, gain: adjustments.compareMode.analysisGain)
            return export(image, colorSpace: baseCGImage.colorSpace)
        }

        guard adjustments.inspector.enabledSections.contains(.compareMode) else {
            return baseCGImage
        }

        if adjustments.blackAndWhite.monochromeCompare,
           adjustments.compareMode.mode == .lumaOnly {
            return baseCGImage
        }

        if adjustments.inspector.enabledSections.contains(.noise),
           adjustments.noise.noiseEmphasisPreview {
            image = applyNoiseEmphasis(image, gain: adjustments.compareMode.analysisGain)
            return export(image, colorSpace: baseCGImage.colorSpace)
        }

        let gain = adjustments.compareMode.analysisGain

        switch adjustments.compareMode.mode {
        case .normal, .absoluteDifference, .deltaE, .blink, .wipe:
            return baseCGImage
        case .lumaOnly:
            image = applyLumaOnly(image)
        case .clippingOverlay:
            image = applyClippingOverlay(image)
        case .falseColor:
            image = applyFalseColor(image, gain: gain)
        case .edgeMap:
            image = applyEdgeMap(image, gain: gain)
        case .noiseEmphasis:
            image = applyNoiseEmphasis(image, gain: gain)
        }

        return export(image, colorSpace: baseCGImage.colorSpace)
    }

    private func export(_ image: CIImage, colorSpace: CGColorSpace?) -> CGImage? {
        let extent = image.extent.integral
        return context.createCGImage(
            image,
            from: extent,
            format: .RGBA8,
            colorSpace: colorSpace ?? fallbackColorSpace
        )
    }

    private func applyLumaOnly(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorMatrix") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 0.2126, y: 0.2126, z: 0.2126, w: 0), forKey: "inputRVector")
        filter.setValue(CIVector(x: 0.7152, y: 0.7152, z: 0.7152, w: 0), forKey: "inputGVector")
        filter.setValue(CIVector(x: 0.0722, y: 0.0722, z: 0.0722, w: 0), forKey: "inputBVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        return filter.outputImage ?? image
    }

    private func applyFalseColor(_ image: CIImage, gain: Double) -> CIImage {
        if
            let gradient = FalseColorLUT.gradientImage(),
            let filter = CIFilter(name: "CIColorMap")
        {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(gradient, forKey: "inputGradientImage")
            if let mapped = filter.outputImage {
                return applyAnalysisGain(mapped, gain: gain)
            }
        }

        guard let filter = CIFilter(name: "CIFalseColor") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIColor(red: 0.05, green: 0.05, blue: 0.45), forKey: "inputColor0")
        filter.setValue(CIColor(red: 1, green: 0.85, blue: 0.1), forKey: "inputColor1")
        return applyAnalysisGain(filter.outputImage ?? image, gain: gain)
    }

    private func applyEdgeMap(_ image: CIImage, gain: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIEdges") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(2.5 * gain, forKey: kCIInputIntensityKey)
        return filter.outputImage ?? image
    }

    private func applyNoiseEmphasis(_ image: CIImage, gain: Double) -> CIImage {
        var result = image

        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0, forKey: kCIInputSaturationKey)
            filter.setValue(0.08 * gain, forKey: kCIInputBrightnessKey)
            filter.setValue(1 + (0.15 * gain), forKey: kCIInputContrastKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        if let filter = CIFilter(name: "CIHighlightShadowAdjust") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.35 * gain, forKey: "inputShadowAmount")
            filter.setValue(0, forKey: "inputHighlightAmount")
            if let output = filter.outputImage {
                result = output
            }
        }

        return result
    }

    private func applyAnalysisGain(_ image: CIImage, gain: Double) -> CIImage {
        guard abs(gain - 1) > 0.001, let filter = CIFilter(name: "CIColorControls") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue((gain - 1) * 0.12, forKey: kCIInputBrightnessKey)
        filter.setValue(gain, forKey: kCIInputContrastKey)
        return filter.outputImage ?? image
    }

    private func applyClippingOverlay(_ image: CIImage) -> CIImage {
        guard
            let threshold = CIFilter(name: "CIColorThreshold"),
            let blend = CIFilter(name: "CIBlendWithMask"),
            let redOverlay = CIFilter(name: "CIConstantColorGenerator"),
            let blueOverlay = CIFilter(name: "CIConstantColorGenerator")
        else {
            return image
        }

        threshold.setValue(image, forKey: kCIInputImageKey)
        threshold.setValue(0.98, forKey: "inputThreshold")
        guard let highlightMask = threshold.outputImage else {
            return image
        }

        redOverlay.setValue(CIColor(red: 1, green: 0, blue: 0, alpha: 0.55), forKey: kCIInputColorKey)
        guard let redImage = redOverlay.outputImage?.cropped(to: image.extent) else {
            return image
        }

        blend.setValue(redImage, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        blend.setValue(highlightMask, forKey: kCIInputMaskImageKey)
        var result = blend.outputImage ?? image

        guard let shadowThreshold = CIFilter(name: "CIColorInvert") else {
            return result
        }

        let lowImage = image.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: -0.45,
            kCIInputContrastKey: 4
        ])

        shadowThreshold.setValue(lowImage, forKey: kCIInputImageKey)
        guard let inverted = shadowThreshold.outputImage else {
            return result
        }

        let shadowMaskFilter = CIFilter(name: "CIColorThreshold")
        shadowMaskFilter?.setValue(inverted, forKey: kCIInputImageKey)
        shadowMaskFilter?.setValue(0.92, forKey: "inputThreshold")
        guard let shadowMask = shadowMaskFilter?.outputImage else {
            return result
        }

        blueOverlay.setValue(CIColor(red: 0.2, green: 0.45, blue: 1, alpha: 0.55), forKey: kCIInputColorKey)
        guard let blueImage = blueOverlay.outputImage?.cropped(to: image.extent) else {
            return result
        }

        blend.setValue(blueImage, forKey: kCIInputImageKey)
        blend.setValue(result, forKey: kCIInputBackgroundImageKey)
        blend.setValue(shadowMask, forKey: kCIInputMaskImageKey)
        if let blended = blend.outputImage {
            result = blended
        }

        return result
    }
}
