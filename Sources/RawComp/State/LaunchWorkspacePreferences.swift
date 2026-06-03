import Foundation

enum LaunchWorkspacePreferences {
    private static let openLastSessionKey = "workspace.openLastSessionOnLaunch"
    private static let exportIncludesLabelsKey = "workspace.exportIncludesLabels"

    static var openLastSessionOnLaunch: Bool {
        get {
            UserDefaults.standard.object(forKey: openLastSessionKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: openLastSessionKey)
        }
    }

    static var exportIncludesLabels: Bool {
        get {
            UserDefaults.standard.object(forKey: exportIncludesLabelsKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: exportIncludesLabelsKey)
        }
    }
}
