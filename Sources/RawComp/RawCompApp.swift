import SwiftUI

@main
struct RawCompApp: App {
    init() {
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
    }
}
