import SwiftUI

struct ContentView: View {
    var store: WorkspaceStore
    var settingsController: AppSettingsController
    @State private var showingAdvancedSettings = false

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar(
                store: store,
                onOpenAdvancedSettings: { showingAdvancedSettings = true }
            )
            Divider()
            HSplitView {
                ComparisonGridView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if store.showInspector {
                    InspectorView(store: store)
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
                }
            }

            Divider()
            WorkspaceStatusBar(message: store.statusMessage)
        }
        .id(settingsController.language.rawValue)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            store.tryOpenLastSessionOnLaunch()
        }
        .sheet(isPresented: $showingAdvancedSettings) {
            AdvancedSettingsView(settingsController: settingsController)
        }
    }
}

private struct AdvancedSettingsView: View {
    @Bindable var settingsController: AppSettingsController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            L10n.text("settings.title")
                .font(.title2.weight(.semibold))

            Form {
                Picker(L10n.string("settings.appearance"), selection: $settingsController.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        L10n.text(theme.titleKey).tag(theme)
                    }
                }

                Picker(L10n.string("settings.language"), selection: $settingsController.language) {
                    ForEach(AppLanguage.allCases) { language in
                        L10n.text(language.titleKey).tag(language)
                    }
                }

                Toggle(
                    L10n.string("settings.autoupdate"),
                    isOn: Binding(
                        get: { settingsController.autoUpdateEnabled },
                        set: { settingsController.setAutoUpdateEnabled($0) }
                    )
                )
                .disabled(!settingsController.canManageAutoUpdate)

                Toggle(
                    L10n.string("settings.open_last_session"),
                    isOn: Binding(
                        get: { LaunchWorkspacePreferences.openLastSessionOnLaunch },
                        set: { LaunchWorkspacePreferences.openLastSessionOnLaunch = $0 }
                    )
                )

                Toggle(
                    L10n.string("settings.export_labels"),
                    isOn: Binding(
                        get: { LaunchWorkspacePreferences.exportIncludesLabels },
                        set: { LaunchWorkspacePreferences.exportIncludesLabels = $0 }
                    )
                )

                HStack {
                    L10n.text("settings.manual_update")
                    Spacer()
                    Button(L10n.string("settings.check_updates"), action: settingsController.checkForUpdates)
                        .disabled(!settingsController.canCheckForUpdates)
                }
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 6) {
                Text(settingsController.canManageAutoUpdate
                    ? L10n.string("settings.footer.available")
                    : L10n.string("settings.footer.unavailable"))
                Text(L10n.string("settings.version", AppVersion.marketingVersion, AppVersion.buildNumber))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button(L10n.string("common.done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
