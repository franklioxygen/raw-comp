import Foundation

struct ComparisonAdjustments: Equatable, Sendable {
    var exposureEV: Double = 0
    var brightness: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var sharpness: Double = 0

    static let neutral = ComparisonAdjustments()

    var isNeutral: Bool {
        self == .neutral
    }

    var statusText: String {
        if isNeutral {
            return L10n.string("adjustments.status.neutral")
        }

        return L10n.string("adjustments.status.active")
    }
}
