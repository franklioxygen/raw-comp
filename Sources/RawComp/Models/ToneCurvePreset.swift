import Foundation

enum ToneCurvePreset: String, CaseIterable, Codable, Sendable {
    case linear
    case softContrast
    case mediumContrast
    case strongContrast

    var titleKey: String {
        "tone_curve.preset.\(rawValue)"
    }
}
