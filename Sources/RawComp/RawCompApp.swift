import Sparkle
import SwiftUI

@main
struct RawCompApp: App {
    @StateObject private var updaterViewModel: CheckForUpdatesViewModel
    private let updaterController: SPUStandardUpdaterController?

    init() {
        let updaterController = SparkleConfiguration.isConfigured
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
        self.updaterController = updaterController
        _updaterViewModel = StateObject(wrappedValue: CheckForUpdatesViewModel(updater: updaterController?.updater))

        Task { @MainActor in
            AppIconController.applyBundledIcon()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 760)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                if let updater = updaterController?.updater {
                    CheckForUpdatesView(updater: updater, viewModel: updaterViewModel)
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

@MainActor
private final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater?) {
        guard let updater else {
            return
        }

        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

private struct CheckForUpdatesView: View {
    let updater: SPUUpdater
    @ObservedObject var viewModel: CheckForUpdatesViewModel

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}
