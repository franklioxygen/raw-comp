import Foundation

enum TopInfoOverlayField: String, CaseIterable, Identifiable, Codable, Sendable {
    case paneTitle = "pane_title"
    case fileName = "file_name"
    case dimensions = "dimensions"
    case fileType = "file_type"
    case fileSize = "file_size"
    case colorModel = "color_model"
    case profileName = "profile_name"
    case pipeline = "pipeline"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paneTitle:
            return L10n.string("top_info.pane")
        case .fileName:
            return L10n.string("inspector.file")
        case .dimensions:
            return L10n.string("inspector.size")
        case .fileType:
            return L10n.string("inspector.type")
        case .fileSize:
            return L10n.string("inspector.disk")
        case .colorModel:
            return L10n.string("inspector.color")
        case .profileName:
            return L10n.string("inspector.profile")
        case .pipeline:
            return L10n.string("inspector.pipeline")
        }
    }

    static let defaultSelectedFieldIDs: Set<String> = [
        TopInfoOverlayField.paneTitle.rawValue,
        TopInfoOverlayField.dimensions.rawValue,
    ]

    static func sortedFieldIDs<S: Sequence>(from fieldIDs: S) -> [String] where S.Element == String {
        let selected = Set(fieldIDs)
        return allCases.map(\.rawValue).filter(selected.contains)
    }
}
