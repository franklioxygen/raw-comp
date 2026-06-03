import Foundation

struct LightAdjustments: Equatable, Sendable, Codable {
    var exposureEV: Double = 0
    var brightness: Double = 0
    var contrast: Double = 1
    var highlights: Double = 0
    var shadows: Double = 0
    var whites: Double = 0
    var blacks: Double = 0
    var gamma: Double = 1

    static let neutral = LightAdjustments()

    var isNeutral: Bool {
        self == .neutral
    }
}

struct ToneCurveAdjustments: Equatable, Sendable, Codable {
    var masterPreset: ToneCurvePreset = .linear
    var redPreset: ToneCurvePreset = .linear
    var greenPreset: ToneCurvePreset = .linear
    var bluePreset: ToneCurvePreset = .linear
    var masterCustomPoints: ToneCurvePoints?
    var redCustomPoints: ToneCurvePoints?
    var greenCustomPoints: ToneCurvePoints?
    var blueCustomPoints: ToneCurvePoints?

    static let neutral = ToneCurveAdjustments()

    var isNeutral: Bool {
        ToneCurveChannel.allCases.allSatisfy(channelIsNeutral)
    }

    func preset(for channel: ToneCurveChannel) -> ToneCurvePreset {
        switch channel {
        case .master: masterPreset
        case .red: redPreset
        case .green: greenPreset
        case .blue: bluePreset
        }
    }

    func customPoints(for channel: ToneCurveChannel) -> ToneCurvePoints? {
        switch channel {
        case .master: masterCustomPoints
        case .red: redCustomPoints
        case .green: greenCustomPoints
        case .blue: blueCustomPoints
        }
    }

    func resolvedPoints(for channel: ToneCurveChannel) -> ToneCurvePoints {
        customPoints(for: channel) ?? ToneCurvePoints(preset: preset(for: channel))
    }

    func usesCustomCurve(for channel: ToneCurveChannel) -> Bool {
        customPoints(for: channel) != nil
    }

    mutating func setPreset(_ preset: ToneCurvePreset, for channel: ToneCurveChannel) {
        setCustomPoints(nil, for: channel)
        switch channel {
        case .master: masterPreset = preset
        case .red: redPreset = preset
        case .green: greenPreset = preset
        case .blue: bluePreset = preset
        }
    }

    mutating func setCustomPoints(_ points: ToneCurvePoints?, for channel: ToneCurveChannel) {
        switch channel {
        case .master: masterCustomPoints = points
        case .red: redCustomPoints = points
        case .green: greenCustomPoints = points
        case .blue: blueCustomPoints = points
        }
    }

    mutating func resetRGB() {
        redPreset = .linear
        greenPreset = .linear
        bluePreset = .linear
        redCustomPoints = nil
        greenCustomPoints = nil
        blueCustomPoints = nil
    }

    mutating func resetMaster() {
        masterPreset = .linear
        masterCustomPoints = nil
    }

    private func channelIsNeutral(_ channel: ToneCurveChannel) -> Bool {
        guard preset(for: channel) == .linear else {
            return false
        }
        guard let custom = customPoints(for: channel) else {
            return true
        }
        return custom.isLinear
    }

    private enum CodingKeys: String, CodingKey {
        case masterPreset
        case redPreset
        case greenPreset
        case bluePreset
        case masterCustomPoints
        case redCustomPoints
        case greenCustomPoints
        case blueCustomPoints
        case preset
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let legacy = try container.decodeIfPresent(ToneCurvePreset.self, forKey: .preset) {
            masterPreset = legacy
            redPreset = .linear
            greenPreset = .linear
            bluePreset = .linear
            return
        }

        masterPreset = try container.decodeIfPresent(ToneCurvePreset.self, forKey: .masterPreset) ?? .linear
        redPreset = try container.decodeIfPresent(ToneCurvePreset.self, forKey: .redPreset) ?? .linear
        greenPreset = try container.decodeIfPresent(ToneCurvePreset.self, forKey: .greenPreset) ?? .linear
        bluePreset = try container.decodeIfPresent(ToneCurvePreset.self, forKey: .bluePreset) ?? .linear
        masterCustomPoints = try container.decodeIfPresent(ToneCurvePoints.self, forKey: .masterCustomPoints)
        redCustomPoints = try container.decodeIfPresent(ToneCurvePoints.self, forKey: .redCustomPoints)
        greenCustomPoints = try container.decodeIfPresent(ToneCurvePoints.self, forKey: .greenCustomPoints)
        blueCustomPoints = try container.decodeIfPresent(ToneCurvePoints.self, forKey: .blueCustomPoints)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(masterPreset, forKey: .masterPreset)
        try container.encode(redPreset, forKey: .redPreset)
        try container.encode(greenPreset, forKey: .greenPreset)
        try container.encode(bluePreset, forKey: .bluePreset)
        try container.encodeIfPresent(masterCustomPoints, forKey: .masterCustomPoints)
        try container.encodeIfPresent(redCustomPoints, forKey: .redCustomPoints)
        try container.encodeIfPresent(greenCustomPoints, forKey: .greenCustomPoints)
        try container.encodeIfPresent(blueCustomPoints, forKey: .blueCustomPoints)
    }
}

struct ColorAdjustments: Equatable, Sendable, Codable {
    var temperature: Double = 0
    var tint: Double = 0
    var vibrance: Double = 0
    var saturationPercent: Double = 100
    var hueShiftDegrees: Double = 0
    var mixer = ColorMixerAdjustments()

    static let neutral = ColorAdjustments()

    var isNeutral: Bool {
        temperature == 0
            && tint == 0
            && vibrance == 0
            && saturationPercent == 100
            && hueShiftDegrees == 0
            && mixer.isNeutral
    }

    var basicIsNeutral: Bool {
        temperature == 0
            && tint == 0
            && vibrance == 0
            && saturationPercent == 100
            && hueShiftDegrees == 0
    }

    var saturationFactor: Double {
        saturationPercent / 100
    }
}

struct BlackAndWhiteAdjustments: Equatable, Sendable, Codable {
    var monochromeCompare: Bool = false
    var redLuminance: Double = 100
    var orangeLuminance: Double = 100
    var yellowLuminance: Double = 100
    var greenLuminance: Double = 100
    var aquaLuminance: Double = 100
    var blueLuminance: Double = 100
    var purpleLuminance: Double = 100
    var magentaLuminance: Double = 100

    static let neutral = BlackAndWhiteAdjustments()

    var isNeutral: Bool {
        !monochromeCompare && mixerIsNeutral
    }

    var mixerIsNeutral: Bool {
        [redLuminance, orangeLuminance, yellowLuminance, greenLuminance, aquaLuminance, blueLuminance, purpleLuminance, magentaLuminance]
            .allSatisfy { $0 == 100 }
    }

    func luminance(for band: ColorBandID) -> Double {
        switch band {
        case .red: redLuminance
        case .orange: orangeLuminance
        case .yellow: yellowLuminance
        case .green: greenLuminance
        case .aqua: aquaLuminance
        case .blue: blueLuminance
        case .purple: purpleLuminance
        case .magenta: magentaLuminance
        }
    }

    mutating func setLuminance(_ value: Double, for band: ColorBandID) {
        switch band {
        case .red: redLuminance = value
        case .orange: orangeLuminance = value
        case .yellow: yellowLuminance = value
        case .green: greenLuminance = value
        case .aqua: aquaLuminance = value
        case .blue: blueLuminance = value
        case .purple: purpleLuminance = value
        case .magenta: magentaLuminance = value
        }
    }
}

struct PresenceAdjustments: Equatable, Sendable, Codable {
    var clarity: Double = 0
    var texture: Double = 0
    var sharpenAmount: Double = 0
    var sharpenRadius: Double = 1.0
    var sharpenDetail: Double = 25
    var sharpenMasking: Double = 0
    var edgeMapPreview: Bool = false

    static let neutral = PresenceAdjustments()

    var isNeutral: Bool {
        clarity == 0
            && texture == 0
            && sharpenAmount == 0
            && sharpenRadius == Self.neutral.sharpenRadius
            && sharpenDetail == Self.neutral.sharpenDetail
            && sharpenMasking == 0
            && !edgeMapPreview
    }
}

struct NoiseAdjustments: Equatable, Sendable, Codable {
    var luminanceNR: Double = 0
    var luminanceDetail: Double = 50
    var luminanceContrast: Double = 0
    var colorNR: Double = 0
    var colorDetail: Double = 50
    var colorSmoothness: Double = 50
    var defringePurple: Double = 0
    var defringeGreen: Double = 0
    var noiseEmphasisPreview: Bool = false

    static let neutral = NoiseAdjustments()

    var isNeutral: Bool {
        luminanceNR == 0
            && luminanceContrast == 0
            && colorNR == 0
            && defringePurple == 0
            && defringeGreen == 0
            && !noiseEmphasisPreview
            && luminanceDetail == 50
            && colorDetail == 50
            && colorSmoothness == 50
    }
}

struct OpticsAdjustments: Equatable, Sendable, Codable {
    var lensProfileCorrection: Bool = false
    var distortionAmount: Double = 0
    var vignettingAmount: Double = 0
    var chromaticAberrationRemoval: Bool = false
    var flatFieldCorrection: Bool = false

    static let neutral = OpticsAdjustments()

    var isNeutral: Bool {
        !lensProfileCorrection
            && distortionAmount == 0
            && vignettingAmount == 0
            && !chromaticAberrationRemoval
            && !flatFieldCorrection
    }
}

struct GeometryAdjustments: Equatable, Sendable, Codable {
    static let defaultCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    var fineRotateDegrees: Double = 0
    var flipHorizontal: Bool = false
    var flipVertical: Bool = false
    var aspectLock: Bool = true
    var showCropOverlay: Bool = false
    var cropRectNormalized: CGRect = defaultCropRect

    static let neutral = GeometryAdjustments()

    var isNeutral: Bool {
        fineRotateDegrees == 0
            && !flipHorizontal
            && !flipVertical
            && !showCropOverlay
            && cropRectNormalized == Self.defaultCropRect
    }
}

struct CompareModeSettings: Equatable, Sendable, Codable {
    var mode: CompareMode = .normal
    var referencePane: CompareReferencePane = .first
    var analysisGain: Double = 1
    var wipePosition: Double = 0.5
    var blinkIntervalSeconds: Double = 0.6

    static let neutral = CompareModeSettings()

    var isNeutral: Bool {
        mode == .normal
    }
}

struct InspectorPresentationState: Equatable, Sendable, Codable {
    var expandedSections: Set<AdjustmentSectionID> = [.histogram, .light, .metadata]
    var enabledSections: Set<AdjustmentSectionID> = [.light, .color, .blackAndWhite, .presence, .geometry, .compareMode]
    var bypassAllAdjustments: Bool = false
    var pixelSampleSize: PixelSampleSize = .one
    var histogramDisplayMode: HistogramDisplayMode = .rgb

    static let `default` = InspectorPresentationState()
}

struct ComparisonAdjustments: Equatable, Sendable {
    var light = LightAdjustments()
    var toneCurve = ToneCurveAdjustments()
    var color = ColorAdjustments()
    var blackAndWhite = BlackAndWhiteAdjustments()
    var presence = PresenceAdjustments()
    var noise = NoiseAdjustments()
    var optics = OpticsAdjustments()
    var geometry = GeometryAdjustments()
    var compareMode = CompareModeSettings()
    var inspector = InspectorPresentationState()

    static let neutral = ComparisonAdjustments()

    var adjustmentValues: ComparisonAdjustmentValues {
        ComparisonAdjustmentValues(from: self)
    }

    var isNeutral: Bool {
        light.isNeutral
            && toneCurve.isNeutral
            && color.isNeutral
            && blackAndWhite.isNeutral
            && presence.isNeutral
            && noise.isNeutral
            && optics.isNeutral
            && geometry.isNeutral
            && compareMode.isNeutral
    }

    var statusText: String {
        if inspector.bypassAllAdjustments {
            return L10n.string("adjustments.status.bypassed")
        }
        if isNeutral && compareMode.isNeutral {
            return L10n.string("adjustments.status.neutral")
        }
        return L10n.string("adjustments.status.active")
    }

    func sectionIsActive(_ section: AdjustmentSectionID) -> Bool {
        guard !inspector.bypassAllAdjustments else {
            return false
        }

        switch section {
        case .histogram, .metadata:
            return false
        case .light:
            return !light.isNeutral
        case .toneCurve:
            return !toneCurve.isNeutral
        case .color:
            return !color.isNeutral
        case .blackAndWhite:
            return !blackAndWhite.isNeutral
        case .presence:
            return !presence.isNeutral
        case .noise:
            return !noise.isNeutral
        case .optics:
            return !optics.isNeutral
        case .geometry:
            return !geometry.isNeutral
        case .compareMode:
            return !compareMode.isNeutral
        }
    }

    mutating func resetSection(_ section: AdjustmentSectionID) {
        switch section {
        case .histogram, .metadata:
            break
        case .light:
            light = .neutral
        case .toneCurve:
            toneCurve = .neutral
        case .color:
            color = .neutral
        case .blackAndWhite:
            blackAndWhite = .neutral
        case .presence:
            presence = .neutral
        case .noise:
            noise = .neutral
        case .optics:
            optics = .neutral
        case .geometry:
            geometry = .neutral
        case .compareMode:
            compareMode = .neutral
        }
    }

    mutating func resetAllAdjustments() {
        light = .neutral
        toneCurve = .neutral
        color = .neutral
        blackAndWhite = .neutral
        presence = .neutral
        noise = .neutral
        optics = .neutral
        geometry = .neutral
        compareMode = .neutral
    }

    mutating func resetColorBasic() {
        color.temperature = 0
        color.tint = 0
        color.vibrance = 0
        color.saturationPercent = 100
        color.hueShiftDegrees = 0
    }

    mutating func resetColorMixer() {
        color.mixer = .neutral
    }

    mutating func resetBlackAndWhiteMixer() {
        blackAndWhite.redLuminance = 100
        blackAndWhite.orangeLuminance = 100
        blackAndWhite.yellowLuminance = 100
        blackAndWhite.greenLuminance = 100
        blackAndWhite.aquaLuminance = 100
        blackAndWhite.blueLuminance = 100
        blackAndWhite.purpleLuminance = 100
        blackAndWhite.magentaLuminance = 100
    }
}
