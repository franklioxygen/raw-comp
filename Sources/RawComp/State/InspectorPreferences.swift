import Foundation

enum InspectorPreferences {
    private static let expandedSectionsKey = "inspector.expandedSections"
    private static let histogramDisplayModeKey = "inspector.histogramDisplayMode"

    static func loadExpandedSections() -> Set<AdjustmentSectionID> {
        guard
            let rawValues = UserDefaults.standard.array(forKey: expandedSectionsKey) as? [String]
        else {
            return InspectorPresentationState.default.expandedSections
        }

        let sections = Set(rawValues.compactMap(AdjustmentSectionID.init(rawValue:)))
        return sections.isEmpty ? InspectorPresentationState.default.expandedSections : sections
    }

    static func saveExpandedSections(_ sections: Set<AdjustmentSectionID>) {
        let rawValues = sections.map(\.rawValue).sorted()
        UserDefaults.standard.set(rawValues, forKey: expandedSectionsKey)
    }

    static func loadHistogramDisplayMode() -> HistogramDisplayMode {
        guard
            let raw = UserDefaults.standard.string(forKey: histogramDisplayModeKey),
            let mode = HistogramDisplayMode(rawValue: raw)
        else {
            return InspectorPresentationState.default.histogramDisplayMode
        }

        return mode
    }

    static func saveHistogramDisplayMode(_ mode: HistogramDisplayMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: histogramDisplayModeKey)
    }
}
