import Foundation

enum ExifOverlayPreferences {
    private static let selectedFieldIDsKey = "exifOverlay.selectedFieldIDs"

    static func loadSelectedFieldIDs() -> Set<String> {
        guard let rawFieldIDs = UserDefaults.standard.array(forKey: selectedFieldIDsKey) as? [String] else {
            return []
        }

        return Set(rawFieldIDs.filter { ExifOverlayField(rawValue: $0) != nil })
    }

    static func saveSelectedFieldIDs(_ fieldIDs: Set<String>) {
        let sortedFieldIDs = ExifOverlayField.sortedFieldIDs(from: fieldIDs)
        UserDefaults.standard.set(sortedFieldIDs, forKey: selectedFieldIDsKey)
    }
}
