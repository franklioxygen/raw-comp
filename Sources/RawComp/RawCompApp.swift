import SwiftUI

@main
struct RawCompApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 760)
        }
        .windowResizability(.contentMinSize)
    }
}
