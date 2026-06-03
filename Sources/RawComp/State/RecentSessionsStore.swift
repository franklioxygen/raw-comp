import Foundation

enum RecentSessionsStore {
    private static let storageKey = "recentComparisonSessions"
    private static let maxEntries = 10

    static func load() -> [URL] {
        guard let paths = UserDefaults.standard.stringArray(forKey: storageKey) else {
            return []
        }

        return paths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    static func record(_ url: URL) {
        var paths = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        let normalized = url.standardizedFileURL.path
        paths.removeAll { $0 == normalized }
        paths.insert(normalized, at: 0)
        if paths.count > maxEntries {
            paths = Array(paths.prefix(maxEntries))
        }
        UserDefaults.standard.set(paths, forKey: storageKey)
    }

    static func remove(_ url: URL) {
        var paths = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        paths.removeAll { $0 == url.standardizedFileURL.path }
        UserDefaults.standard.set(paths, forKey: storageKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
