import Sparkle
import SwiftUI

@main
struct RawCompApp: App {
    @StateObject private var settingsController: AppSettingsController
    private let updaterController: SPUStandardUpdaterController?

    init() {
        let updaterController = SparkleConfiguration.isConfigured
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
        self.updaterController = updaterController
        _settingsController = StateObject(wrappedValue: AppSettingsController(updater: updaterController?.updater))

        Task { @MainActor in
            AppIconController.applyBundledIcon()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(settingsController: settingsController)
                .frame(minWidth: 1200, minHeight: 760)
                .preferredColorScheme(settingsController.colorScheme)
                .environment(\.locale, settingsController.locale)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                if settingsController.canManageAutoUpdate {
                    Button(L10n.string("settings.check_updates"), action: settingsController.checkForUpdates)
                        .disabled(!settingsController.canCheckForUpdates)
                }
            }
        }
    }
}

private enum SparkleConfiguration {
    static var isConfigured: Bool {
        guard
            let infoDictionary = Bundle.main.infoDictionary,
            let feedURL = infoDictionary["SUFeedURL"] as? String,
            let publicKey = infoDictionary["SUPublicEDKey"] as? String
        else {
            return false
        }

        return !feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
