import CoreGraphics
@preconcurrency import CoreImage
import Foundation

actor ImageAdjustmentRenderer {
    static let shared = ImageAdjustmentRenderer()

    private let context = CIContext()
    private let fallbackColorSpace = CGColorSpace(name: CGColorSpace.sRGB)

    func render(
        _ loadedImage: LoadedImage,
        adjustments: ComparisonAdjustments,
        forceBypass: Bool = false,
        maxPreviewDimension: Int? = nil
    ) async -> CGImage? {
        let sourceCGImage = await ImageDecodeRenderer.shared.baseCGImage(
            for: loadedImage,
            maxPreviewDimension: maxPreviewDimension
        )

        if forceBypass || adjustments.inspector.bypassAllAdjustments {
            return sourceCGImage
        }

        let inspector = adjustments.inspector
        let monochrome = adjustments.blackAndWhite.monochromeCompare
            && inspector.enabledSections.contains(.blackAndWhite)

        let appliesLight = inspector.enabledSections.contains(.light) && !adjustments.light.isNeutral
        let appliesTone = inspector.enabledSections.contains(.toneCurve) && !adjustments.toneCurve.isNeutral
        let appliesColor = inspector.enabledSections.contains(.color) && !monochrome && !adjustments.color.isNeutral
        let appliesPresence = inspector.enabledSections.contains(.presence) && !adjustments.presence.isNeutral
        let appliesNoise = inspector.enabledSections.contains(.noise) && !adjustments.noise.isNeutral
        let appliesOptics = inspector.enabledSections.contains(.optics) && !adjustments.optics.isNeutral
        let appliesGeometry = inspector.enabledSections.contains(.geometry) && !adjustments.geometry.isNeutral
        let appliesBWWeights = monochrome && !adjustments.blackAndWhite.mixerIsNeutral

        guard
            appliesLight || appliesTone || appliesColor || monochrome || appliesPresence
            || appliesNoise || appliesOptics || appliesGeometry || appliesBWWeights
        else {
            return sourceCGImage
        }

        var image = CIImage(cgImage: sourceCGImage)

        if appliesLight {
            image = applyLight(image, light: adjustments.light)
        }

        if appliesTone {
            image = applyToneCurve(image, toneCurve: adjustments.toneCurve)
        }

        if appliesColor {
            image = applyColor(image, color: adjustments.color)
        }

        if monochrome {
            image = applyMonochrome(image, blackAndWhite: adjustments.blackAndWhite)
        }

        if appliesPresence {
            image = applyPresence(image, presence: adjustments.presence)
        }

        if appliesNoise {
            image = applyNoise(image, noise: adjustments.noise)
        }

        if appliesOptics {
            image = applyOptics(
                image,
                optics: adjustments.optics,
                usesRawPipeline: loadedImage.metadata.usesRawPipeline
            )
        }

        if appliesGeometry {
            image = applyGeometry(image, geometry: adjustments.geometry)
        }

        let extent = image.extent.integral
        let colorSpace = sourceCGImage.colorSpace ?? fallbackColorSpace
        return context.createCGImage(image, from: extent, format: .RGBA8, colorSpace: colorSpace)
    }

    private func applyLight(_ image: CIImage, light: LightAdjustments) -> CIImage {
        var result = image

        if light.exposureEV != 0, let filter = CIFilter(name: "CIExposureAdjust") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(light.exposureEV, forKey: kCIInputEVKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        if light.highlights != 0 || light.shadows != 0, let filter = CIFilter(name: "CIHighlightShadowAdjust") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(light.shadows / 100, forKey: "inputShadowAmount")
            filter.setValue(light.highlights / 100, forKey: "inputHighlightAmount")
            if let output = filter.outputImage {
                result = output
            }
        }

        if light.whites != 0 || light.blacks != 0, let filter = CIFilter(name: "CIColorClamp") {
            let maxValue = min(1, 1 - (light.whites / 100) * 0.15)
            let minValue = max(0, (light.blacks / 100) * 0.15)
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: minValue, y: minValue, z: minValue, w: 1), forKey: "inputMinComponents")
            filter.setValue(CIVector(x: maxValue, y: maxValue, z: maxValue, w: 1), forKey: "inputMaxComponents")
            if let output = filter.outputImage {
                result = output
            }
        }

        if light.gamma != 1, let filter = CIFilter(name: "CIGammaAdjust") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(light.gamma, forKey: "inputPower")
            if let output = filter.outputImage {
                result = output
            }
        }

        if light.brightness != 0 || light.contrast != 1, let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(light.brightness, forKey: kCIInputBrightnessKey)
            filter.setValue(light.contrast, forKey: kCIInputContrastKey)
            filter.setValue(1.0, forKey: kCIInputSaturationKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        return result
    }

    private func applyToneCurve(_ image: CIImage, toneCurve: ToneCurveAdjustments) -> CIImage {
        var result = image
        for channel in ToneCurveChannel.allCases {
            let points = toneCurve.resolvedPoints(for: channel)
            guard !points.isLinear else {
                continue
            }
            result = applyToneCurveChannel(
                result,
                points: points,
                channel: channel,
                original: image
            )
        }
        return result
    }

    private func applyToneCurveChannel(
        _ image: CIImage,
        points: ToneCurvePoints,
        channel: ToneCurveChannel,
        original: CIImage
    ) -> CIImage {
        guard let curved = applyMasterToneCurve(image, points: points) else {
            return image
        }

        guard channel != .master else {
            return curved
        }

        guard
            let mask = HueMaskGenerator.maskImage(
                for: original,
                target: .toneChannel(channel),
                context: context
            )
        else {
            return curved
        }

        return ColorMixerHueMask.blend(original: image, adjusted: curved, mask: mask)
    }

    private func applyMasterToneCurve(_ image: CIImage, points: ToneCurvePoints) -> CIImage? {
        guard let filter = CIFilter(name: "CIToneCurve") else {
            return nil
        }

        let controlPoints = ToneCurveLUT.ciPoints(from: points)
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: controlPoints.0.x, y: controlPoints.0.y), forKey: "inputPoint0")
        filter.setValue(CIVector(x: controlPoints.1.x, y: controlPoints.1.y), forKey: "inputPoint1")
        filter.setValue(CIVector(x: controlPoints.2.x, y: controlPoints.2.y), forKey: "inputPoint2")
        filter.setValue(CIVector(x: controlPoints.3.x, y: controlPoints.3.y), forKey: "inputPoint3")
        filter.setValue(CIVector(x: controlPoints.4.x, y: controlPoints.4.y), forKey: "inputPoint4")
        return filter.outputImage
    }

    private func applyColor(_ image: CIImage, color: ColorAdjustments) -> CIImage {
        var result = image

        if color.temperature != 0 || color.tint != 0, let filter = CIFilter(name: "CITemperatureAndTint") {
            let neutral = CIVector(x: 6500, y: 0)
            let target = CIVector(
                x: 6500 + (color.temperature * 35),
                y: color.tint * 0.5
            )
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(neutral, forKey: "inputNeutral")
            filter.setValue(target, forKey: "inputTargetNeutral")
            if let output = filter.outputImage {
                result = output
            }
        }

        if color.vibrance != 0, let filter = CIFilter(name: "CIVibrance") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(color.vibrance / 100, forKey: "inputAmount")
            if let output = filter.outputImage {
                result = output
            }
        }

        if color.hueShiftDegrees != 0, let filter = CIFilter(name: "CIHueAdjust") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(color.hueShiftDegrees * .pi / 180, forKey: kCIInputAngleKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        let saturation = color.saturationFactor
        if saturation != 1, let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0, forKey: kCIInputBrightnessKey)
            filter.setValue(1, forKey: kCIInputContrastKey)
            filter.setValue(saturation, forKey: kCIInputSaturationKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        if !color.mixer.isNeutral {
            result = applyColorMixer(result, mixer: color.mixer)
        }

        return result
    }

    private func applyColorMixer(_ image: CIImage, mixer: ColorMixerAdjustments) -> CIImage {
        var result = image
        for band in ColorBandID.allCases {
            let bandMixer = mixer.mixer(for: band)
            guard !bandMixer.isNeutral else {
                continue
            }

            let adjusted = applyColorBand(result, mixer: bandMixer)
            guard let mask = ColorMixerHueMask.maskImage(for: result, band: band, context: context) else {
                result = adjusted
                continue
            }

            result = ColorMixerHueMask.blend(original: result, adjusted: adjusted, mask: mask)
        }

        return result
    }

    private func applyColorBand(_ image: CIImage, mixer: ColorBandMixer) -> CIImage {
        var result = image

        if mixer.hue != 0, let filter = CIFilter(name: "CIHueAdjust") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(mixer.hue * .pi / 180, forKey: kCIInputAngleKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        if mixer.saturation != 0, let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(1 + (mixer.saturation / 100), forKey: kCIInputSaturationKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        if mixer.luminance != 0, let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(mixer.luminance / 200, forKey: kCIInputBrightnessKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        return result
    }

    private func applyMonochrome(_ image: CIImage, blackAndWhite: BlackAndWhiteAdjustments) -> CIImage {
        let weights = monochromeWeights(from: blackAndWhite)
        guard let filter = CIFilter(name: "CIColorMatrix") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: weights.x, y: weights.x, z: weights.x, w: 0), forKey: "inputRVector")
        filter.setValue(CIVector(x: weights.y, y: weights.y, z: weights.y, w: 0), forKey: "inputGVector")
        filter.setValue(CIVector(x: weights.z, y: weights.z, z: weights.z, w: 0), forKey: "inputBVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")
        return filter.outputImage ?? image
    }

    private func monochromeWeights(from blackAndWhite: BlackAndWhiteAdjustments) -> (x: CGFloat, y: CGFloat, z: CGFloat) {
        let red = blackAndWhite.redLuminance / 100
        let orange = blackAndWhite.orangeLuminance / 100
        let yellow = blackAndWhite.yellowLuminance / 100
        let green = blackAndWhite.greenLuminance / 100
        let aqua = blackAndWhite.aquaLuminance / 100
        let blue = blackAndWhite.blueLuminance / 100
        let purple = blackAndWhite.purpleLuminance / 100
        let magenta = blackAndWhite.magentaLuminance / 100

        let rx = 0.2126 * red + 0.04 * orange
        let gy = 0.7152 * green + 0.05 * yellow + 0.04 * aqua
        let bz = 0.0722 * blue + 0.04 * purple + 0.04 * magenta
        let sum = max(rx + gy + bz, 0.001)
        return (rx / sum, gy / sum, bz / sum)
    }

    private func applyNoise(_ image: CIImage, noise: NoiseAdjustments) -> CIImage {
        var result = image

        if noise.luminanceNR > 0, let filter = CIFilter(name: "CINoiseReduction") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(noise.luminanceNR / 100, forKey: "inputNoiseLevel")
            filter.setValue(noise.luminanceDetail / 100, forKey: "inputSharpness")
            if let output = filter.outputImage {
                result = output
            }
        }

        if noise.colorNR > 0 {
            let sigma = noise.colorNR / 35
            let blurred = result.applyingGaussianBlur(sigma: sigma)
            // Blend chroma from the blurred image with luma from the original:
            // convert both to luma-only, subtract to get a chroma-restore mask,
            // then use CIColorBlendMode to take hue/saturation from blurred and
            // luminosity from the unblurred source.
            if let blend = CIFilter(name: "CIColorBlendMode") {
                blend.setValue(blurred, forKey: kCIInputImageKey)
                blend.setValue(result, forKey: kCIInputBackgroundImageKey)
                if let output = blend.outputImage {
                    let strength = 1 - (noise.colorNR / 200)
                    result = output.applyingFilter("CIColorControls", parameters: [
                        kCIInputSaturationKey: max(0, strength)
                    ])
                }
            }
        }

        if noise.defringePurple > 0 || noise.defringeGreen > 0, let filter = CIFilter(name: "CIVibrance") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(-(noise.defringePurple + noise.defringeGreen) / 200, forKey: "inputAmount")
            if let output = filter.outputImage {
                result = output
            }
        }

        return result
    }

    private func applyOptics(
        _ image: CIImage,
        optics: OpticsAdjustments,
        usesRawPipeline: Bool
    ) -> CIImage {
        var result = image

        if optics.flatFieldCorrection {
            result = applyFlatFieldCorrection(result, usesRawPipeline: usesRawPipeline)
        }

        var distortionAmount = optics.distortionAmount
        var vignettingAmount = optics.vignettingAmount
        var chromaticRemoval = optics.chromaticAberrationRemoval
        if optics.lensProfileCorrection {
            distortionAmount += -14
            vignettingAmount += -22
            chromaticRemoval = true
        }

        if vignettingAmount != 0, let filter = CIFilter(name: "CIVignette") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(vignettingAmount / 50, forKey: kCIInputIntensityKey)
            filter.setValue(1.2, forKey: kCIInputRadiusKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        // CIPinchDistortion produces a creative barrel/pincushion effect, not a physical lens model.
        if distortionAmount != 0, let filter = CIFilter(name: "CIPinchDistortion") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(distortionAmount / 400, forKey: kCIInputScaleKey)
            filter.setValue(CIVector(x: result.extent.midX, y: result.extent.midY), forKey: kCIInputCenterKey)
            filter.setValue(min(result.extent.width, result.extent.height) * 0.45, forKey: kCIInputRadiusKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        if chromaticRemoval, let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.98, forKey: kCIInputSaturationKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        return result
    }

    private func applyFlatFieldCorrection(_ image: CIImage, usesRawPipeline: Bool) -> CIImage {
        let sigma: Double = usesRawPipeline ? 90 : 55
        let blurred = image.clampedToExtent().applyingGaussianBlur(sigma: sigma)
        let clampedBlur = blurred.applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0.08, y: 0.08, z: 0.08, w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])

        guard let filter = CIFilter(name: "CIDivideBlendMode") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(clampedBlur, forKey: kCIInputBackgroundImageKey)
        guard let divided = filter.outputImage else {
            return image
        }

        return divided.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: usesRawPipeline ? 0 : -0.02,
            kCIInputContrastKey: 1.04,
            kCIInputSaturationKey: 1
        ])
    }

    private func applyPresence(_ image: CIImage, presence: PresenceAdjustments) -> CIImage {
        var result = image

        if presence.clarity != 0, let filter = CIFilter(name: "CIUnsharpMask") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(12, forKey: kCIInputRadiusKey)
            filter.setValue(presence.clarity / 80, forKey: kCIInputIntensityKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        if presence.texture != 0, let filter = CIFilter(name: "CIUnsharpMask") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(2.5, forKey: kCIInputRadiusKey)
            filter.setValue(presence.texture / 120, forKey: kCIInputIntensityKey)
            if let output = filter.outputImage {
                result = output
            }
        }

        if presence.sharpenAmount > 0 {
            let detailScale = 0.5 + (presence.sharpenDetail / 100)
            let sharpened: CIImage
            if let filter = CIFilter(name: "CISharpenLuminance") {
                filter.setValue(result, forKey: kCIInputImageKey)
                filter.setValue((presence.sharpenAmount / 100) * detailScale, forKey: kCIInputSharpnessKey)
                filter.setValue(presence.sharpenRadius, forKey: kCIInputRadiusKey)
                sharpened = filter.outputImage ?? result
            } else {
                sharpened = result
            }

            if presence.sharpenMasking > 0, let mask = edgeSharpenMask(for: result, amount: presence.sharpenMasking / 100) {
                result = blendWithMask(original: result, adjusted: sharpened, mask: mask)
            } else {
                result = sharpened
            }
        }

        return result
    }

    private func edgeSharpenMask(for image: CIImage, amount: Double) -> CIImage? {
        guard amount > 0, let filter = CIFilter(name: "CIEdges") else {
            return nil
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.5, forKey: kCIInputIntensityKey)
        guard let edges = filter.outputImage else {
            return nil
        }

        return edges.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 1 + amount,
            kCIInputBrightnessKey: -0.05 * amount
        ])
    }

    private func blendWithMask(original: CIImage, adjusted: CIImage, mask: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            return adjusted
        }

        filter.setValue(adjusted, forKey: kCIInputImageKey)
        filter.setValue(original, forKey: kCIInputBackgroundImageKey)
        filter.setValue(mask, forKey: kCIInputMaskImageKey)
        return filter.outputImage ?? adjusted
    }

    private func applyGeometry(_ image: CIImage, geometry: GeometryAdjustments) -> CIImage {
        var transform = CGAffineTransform.identity

        if geometry.flipHorizontal {
            transform = transform
                .translatedBy(x: image.extent.width, y: 0)
                .scaledBy(x: -1, y: 1)
        }

        if geometry.flipVertical {
            transform = transform
                .translatedBy(x: 0, y: image.extent.height)
                .scaledBy(x: 1, y: -1)
        }

        if geometry.fineRotateDegrees != 0 {
            let radians = geometry.fineRotateDegrees * .pi / 180
            let centerX = image.extent.midX
            let centerY = image.extent.midY
            transform = transform
                .translatedBy(x: centerX, y: centerY)
                .rotated(by: radians)
                .translatedBy(x: -centerX, y: -centerY)
        }

        var result = transform == .identity ? image : image.transformed(by: transform)

        if geometry.cropRectNormalized != GeometryAdjustments.defaultCropRect {
            let rect = geometry.cropRectNormalized.clampedUnit()
            let extent = result.extent
            let crop = CGRect(
                x: extent.minX + (rect.minX * extent.width),
                y: extent.minY + (rect.minY * extent.height),
                width: rect.width * extent.width,
                height: rect.height * extent.height
            ).integral
            result = result.cropped(to: crop)
        }

        return result
    }
}
