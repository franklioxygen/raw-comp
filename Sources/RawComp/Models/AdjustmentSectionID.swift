import Foundation

enum AdjustmentSectionID: String, CaseIterable, Codable, Sendable, Hashable {
    case histogram
    case light
    case toneCurve
    case color
    case blackAndWhite
    case presence
    case noise
    case optics
    case geometry
    case compareMode
    case metadata

    var titleKey: String {
        "inspector.section.\(rawValue)"
    }

    var isAdjustmentSection: Bool {
        self != .histogram && self != .metadata
    }
}
