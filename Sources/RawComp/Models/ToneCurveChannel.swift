import Foundation

enum ToneCurveChannel: String, CaseIterable, Codable, Sendable {
    case master
    case red
    case green
    case blue

    var titleKey: String {
        "tone_curve.channel.\(rawValue)"
    }
}
