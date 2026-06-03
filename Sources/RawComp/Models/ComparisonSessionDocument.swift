import Foundation

struct PaneSessionState: Codable, Sendable {
    var slot: Int
    var filePath: String
    var viewport: ViewportState?
}

struct ComparisonSessionDocument: Codable, Sendable {
    static let currentVersion = 1

    var version: Int = currentVersion
    var layout: ComparisonLayout = .two
    var linkMode: LinkMode = .synced
    var adjustments: ComparisonAdjustmentValues = ComparisonAdjustmentValues()
    var inspector: InspectorPresentationState?
    var opticsByFilePath: [String: OpticsAdjustments] = [:]
    var panes: [PaneSessionState] = []

    /// Applies forward migrations for older session documents.
    /// Extend this switch when the version number increases.
    static func migrate(_ document: ComparisonSessionDocument) -> ComparisonSessionDocument {
        switch document.version {
        case currentVersion:
            return document
        default:
            // Unknown future version: return as-is and let missing fields use defaults.
            return document
        }
    }
}
