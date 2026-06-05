import Foundation

enum TopInfoOverlayPreferences {
    private static let selectedFieldIDsKey = "topInfoOverlay.selectedFieldIDs"

    static func loadSelectedFieldIDs() -> Set<String> {
        guard UserDefaults.standard.object(forKey: selectedFieldIDsKey) != nil else {
            return TopInfoOverlayField.defaultSelectedFieldIDs
        }

        guard let rawFieldIDs = UserDefaults.standard.array(forKey: selectedFieldIDsKey) as? [String] else {
            return TopInfoOverlayField.defaultSelectedFieldIDs
        }

        return Set(rawFieldIDs.filter { TopInfoOverlayField(rawValue: $0) != nil })
    }

    static func saveSelectedFieldIDs(_ fieldIDs: Set<String>) {
        let sortedFieldIDs = TopInfoOverlayField.sortedFieldIDs(from: fieldIDs)
        UserDefaults.standard.set(sortedFieldIDs, forKey: selectedFieldIDsKey)
    }
}
