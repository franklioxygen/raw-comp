import Sparkle
import SwiftUI
import os.log

@main
struct RawCompApp: App {
    @State private var workspaceStore = WorkspaceStore()
    @State private var settingsController: AppSettingsController
    private let updaterController: SPUStandardUpdaterController?

    init() {
        let settingsController = AppSettingsController(updater: nil)
        _settingsController = State(initialValue: settingsController)

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
            ContentView(store: workspaceStore, settingsController: settingsController)
                .frame(minWidth: 1200, minHeight: 760)
                .preferredColorScheme(settingsController.colorScheme)
                .environment(\.locale, settingsController.locale)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .saveItem) {
                Button(L10n.string("toolbar.save_session"), action: workspaceStore.saveSessionToFile)
                    .keyboardShortcut("s", modifiers: [.command, .shift])

                Button(L10n.string("toolbar.open_session"), action: workspaceStore.openSessionFromFile)
                    .keyboardShortcut("o", modifiers: [.command, .shift])

                Button(L10n.string("toolbar.export_comparison"), action: workspaceStore.exportComparisonToFile)
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            CommandGroup(after: .sidebar) {
                Button(
                    workspaceStore.showInspector
                        ? L10n.string("toolbar.hide_inspector")
                        : L10n.string("toolbar.show_inspector"),
                    action: workspaceStore.toggleInspector
                )
                .keyboardShortcut("i", modifiers: [.command, .option])
            }

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
