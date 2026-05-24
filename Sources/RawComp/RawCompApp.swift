import Sparkle
import SwiftUI
import os.log

@main
struct RawCompApp: App {
    @StateObject private var settingsController: AppSettingsController
    private let updaterController: SPUStandardUpdaterController?

    init() {
        let settingsController = AppSettingsController(updater: nil)
        _settingsController = StateObject(wrappedValue: settingsController)

        let updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        self.updaterController = updaterController

        let updater: SPUUpdater?
        do {
            try updaterController.updater.start()
            updater = updaterController.updater
        } catch {
            Logger.updater.warning("Sparkle updater failed to start: \(error.localizedDescription, privacy: .public)")
            updater = nil
        }

        settingsController.attachUpdater(updater)

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

private extension Logger {
    static let updater = Logger(subsystem: "com.rawcomp.app", category: "updater")
}
