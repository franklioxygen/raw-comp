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
        L10n.string("layout.title", rawValue)
    }

    var menuIconSystemName: String {
        switch self {
        case .two:
            "rectangle.split.2x1"
        case .three:
            "rectangle.split.3x1"
        case .four:
            "square.grid.2x2"
        case .six:
            "square.grid.3x2"
        }
    }
}
