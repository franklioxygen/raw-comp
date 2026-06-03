import Foundation

enum PaneOpticsStore {
    private static let storageKey = "comparison.optics.byPath"

    static func load() -> [String: OpticsAdjustments] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: OpticsAdjustments].self, from: data)
        else {
            return [:]
        }

        return decoded
    }

    static func save(_ map: [String: OpticsAdjustments]) {
        guard let data = try? JSONEncoder().encode(map) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
