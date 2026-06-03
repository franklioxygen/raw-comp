import Foundation

enum ColorBandID: String, CaseIterable, Codable, Sendable, Hashable {
    case red
    case orange
    case yellow
    case green
    case aqua
    case blue
    case purple
    case magenta

    var titleKey: String {
        "color_band.\(rawValue)"
    }

    var centerHueDegrees: Double {
        switch self {
        case .red: 0
        case .orange: 30
        case .yellow: 60
        case .green: 120
        case .aqua: 180
        case .blue: 240
        case .purple: 270
        case .magenta: 300
        }
    }

    var hueWidthDegrees: Double { 28 }
}

struct ColorBandMixer: Equatable, Sendable, Codable {
    var hue: Double = 0
    var saturation: Double = 0
    var luminance: Double = 0

    var isNeutral: Bool {
        hue == 0 && saturation == 0 && luminance == 0
    }
}

struct ColorMixerAdjustments: Equatable, Sendable, Codable {
    var red = ColorBandMixer()
    var orange = ColorBandMixer()
    var yellow = ColorBandMixer()
    var green = ColorBandMixer()
    var aqua = ColorBandMixer()
    var blue = ColorBandMixer()
    var purple = ColorBandMixer()
    var magenta = ColorBandMixer()

    static let neutral = ColorMixerAdjustments()

    var isNeutral: Bool {
        ColorBandID.allCases.allSatisfy { band in
            mixer(for: band).isNeutral
        }
    }

    mutating func reset() {
        self = .neutral
    }

    func mixer(for band: ColorBandID) -> ColorBandMixer {
        switch band {
        case .red: red
        case .orange: orange
        case .yellow: yellow
        case .green: green
        case .aqua: aqua
        case .blue: blue
        case .purple: purple
        case .magenta: magenta
        }
    }

    mutating func setMixer(_ mixer: ColorBandMixer, for band: ColorBandID) {
        switch band {
        case .red: red = mixer
        case .orange: orange = mixer
        case .yellow: yellow = mixer
        case .green: green = mixer
        case .aqua: aqua = mixer
        case .blue: blue = mixer
        case .purple: purple = mixer
        case .magenta: magenta = mixer
        }
    }
}
