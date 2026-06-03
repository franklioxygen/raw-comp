import Foundation

enum ComparisonLayout: Int, CaseIterable, Identifiable, Sendable, Codable {
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

    var menuLabel: String {
        switch self {
        case .two:
            "2 Panes"
        case .three:
            "3 Panes"
        case .four:
            "4 Panes"
        case .six:
            "6 Panes"
        }
    }

    static func bestFit(forPaneCount paneCount: Int) -> ComparisonLayout {
        switch max(paneCount, 0) {
        case 0...2:
            .two
        case 3:
            .three
        case 4:
            .four
        default:
            .six
        }
    }

    static func restoredLayout(_ stored: ComparisonLayout, paneStates: [PaneSessionState]) -> ComparisonLayout {
        let highestSlot = (paneStates.map(\.slot).max() ?? -1) + 1
        let requiredPaneCount = max(paneStates.count, highestSlot)
        guard requiredPaneCount > stored.paneCount else {
            return stored
        }

        return bestFit(forPaneCount: requiredPaneCount)
    }
}
