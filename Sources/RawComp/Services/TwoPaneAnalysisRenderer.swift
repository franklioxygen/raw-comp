import CoreGraphics
@preconcurrency import CoreImage
import Foundation

actor TwoPaneAnalysisRenderer {
    static let shared = TwoPaneAnalysisRenderer()

    private let context = CIContext()
    private let fallbackColorSpace = CGColorSpace(name: CGColorSpace.sRGB)

    func render(
        leftImage: CGImage,
        rightImage: CGImage,
        mode: CompareMode,
        settings: CompareModeSettings
    ) -> CGImage? {
        let left = CIImage(cgImage: leftImage)
        let right = CIImage(cgImage: rightImage)
        let aligned = alignImages(left: left, right: right)
        let reference = settings.referencePane == .first ? aligned.left : aligned.right
        let target = settings.referencePane == .first ? aligned.right : aligned.left

        let output: CIImage
        switch mode {
        case .absoluteDifference:
            output = applyAbsoluteDifference(reference, target, gain: settings.analysisGain)
        case .deltaE:
            output = applyDeltaE(reference, target, gain: settings.analysisGain)
        case .wipe:
            output = applyWipe(aligned.left, aligned.right, position: settings.wipePosition)
        case .blink:
            // Blink alternation is driven by WorkspaceStore.displayCGImage(for:);
            // the renderer returns the reference frame for any non-WorkspaceStore callers.
            output = aligned.reference
        default:
            return leftImage
        }

        return export(output, colorSpace: leftImage.colorSpace ?? rightImage.colorSpace)
    }

    private struct AlignedPair {
        let left: CIImage
        let right: CIImage
        let reference: CIImage
    }

    private func alignImages(left: CIImage, right: CIImage) -> AlignedPair {
        let targetExtent = left.extent

        let scaleX = targetExtent.width / max(right.extent.width, 1)
        let scaleY = targetExtent.height / max(right.extent.height, 1)
        let uniformScale = min(scaleX, scaleY)

        let scaledRight = right.transformed(by: CGAffineTransform(scaleX: uniformScale, y: uniformScale))
        let scaledExtent = scaledRight.extent

        let offsetX = targetExtent.midX - scaledExtent.midX
        let offsetY = targetExtent.midY - scaledExtent.midY
        let centeredRight = scaledRight
            .transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
            .cropped(to: targetExtent)

        let croppedLeft = left.cropped(to: targetExtent)
        return AlignedPair(left: croppedLeft, right: centeredRight, reference: croppedLeft)
    }

    private func applyAbsoluteDifference(_ left: CIImage, _ right: CIImage, gain: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIColorAbsoluteDifference") else {
            return left
        }

        filter.setValue(left, forKey: kCIInputImageKey)
        filter.setValue(right, forKey: "inputImage2")
        guard var output = filter.outputImage else {
            return left
        }

        if gain != 1, let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(output, forKey: kCIInputImageKey)
            controls.setValue((gain - 1) * 0.35, forKey: kCIInputBrightnessKey)
            controls.setValue(gain, forKey: kCIInputContrastKey)
            output = controls.outputImage ?? output
        }

        return output
    }

    private func applyDeltaE(_ left: CIImage, _ right: CIImage, gain: Double) -> CIImage {
        guard let filter = CIFilter(name: "CILabDeltaE") else {
            return applyAbsoluteDifference(left, right, gain: gain)
        }

        filter.setValue(left, forKey: kCIInputImageKey)
        filter.setValue(right, forKey: "inputImage2")
        guard var output = filter.outputImage else {
            return left
        }

        if gain != 1, let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(output, forKey: kCIInputImageKey)
            controls.setValue(gain, forKey: kCIInputContrastKey)
            output = controls.outputImage ?? output
        }

        return output
    }

    private func applyWipe(_ left: CIImage, _ right: CIImage, position: Double) -> CIImage {
        let extent = left.extent
        let splitX = extent.minX + (extent.width * position.clamped01)

        guard
            let gradient = CIFilter(name: "CILinearGradient"),
            let blend = CIFilter(name: "CIBlendWithMask")
        else {
            return left
        }

        gradient.setValue(CIVector(x: splitX - 1, y: extent.midY), forKey: "inputPoint0")
        gradient.setValue(CIVector(x: splitX + 1, y: extent.midY), forKey: "inputPoint1")
        gradient.setValue(CIColor.white, forKey: "inputColor0")
        gradient.setValue(CIColor.black, forKey: "inputColor1")

        guard let mask = gradient.outputImage?.cropped(to: extent) else {
            return left
        }

        blend.setValue(right, forKey: kCIInputImageKey)
        blend.setValue(left, forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask, forKey: kCIInputMaskImageKey)
        return blend.outputImage ?? left
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
}

private extension Double {
    var clamped01: Double {
        Swift.min(Swift.max(self, 0), 1)
    }
}
