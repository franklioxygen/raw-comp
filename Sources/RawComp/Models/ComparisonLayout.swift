import Foundation

enum ComparisonLayout: Int, CaseIterable, Identifiable, Sendable {
    case two = 2
    case three = 3
    case four = 4
    case six = 6

    var id: Int { rawValue }

    var paneCount: Int { rawValue }

    var columnCount: Int {
        switch self {
        case .two:
            2
        case .three:
            3
        case .four:
            2
        case .six:
            3
        }
    }

    var title: String {
        "\(rawValue) Up"
    }
}
