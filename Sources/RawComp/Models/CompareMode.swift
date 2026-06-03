import Foundation

enum CompareMode: String, CaseIterable, Codable, Sendable, Hashable {
    case normal
    case lumaOnly
    case clippingOverlay
    case falseColor
    case edgeMap
    case noiseEmphasis
    case absoluteDifference
    case deltaE
    case blink
    case wipe

    var titleKey: String {
        "compare.mode.\(rawValue)"
    }

    var requiresTwoPanes: Bool {
        switch self {
        case .absoluteDifference, .deltaE, .blink, .wipe:
            true
        default:
            false
        }
    }

    static func cases(for layout: ComparisonLayout) -> [CompareMode] {
        allCases.filter { mode in
            !mode.requiresTwoPanes || layout == .two
        }
    }
}

enum CompareReferencePane: Int, CaseIterable, Codable, Sendable, Hashable {
    case first = 0
    case second = 1

    var titleKey: String {
        "compare.reference.\(rawValue)"
    }
}
