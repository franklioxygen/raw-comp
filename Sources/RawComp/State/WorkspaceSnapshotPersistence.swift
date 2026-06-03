import Foundation

struct WorkspaceSnapshot: Codable, Sendable {
    var layout: ComparisonLayout = .two
    var linkMode: LinkMode = .synced
    var panes: [PaneSessionState] = []
}

enum WorkspaceSnapshotPersistence {
    private static let storageKey = "workspace.snapshot"

    static func load() -> WorkspaceSnapshot? {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let snapshot = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
        else {
            return nil
        }

        return snapshot.panes.isEmpty ? nil : snapshot
    }

    static func save(_ snapshot: WorkspaceSnapshot) {
        guard !snapshot.panes.isEmpty else {
            clear()
            return
        }

        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
