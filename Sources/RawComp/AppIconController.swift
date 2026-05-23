import AppKit
import Foundation

enum AppIconController {
    @MainActor
    static func applyBundledIcon() {
        guard
            let url = Bundle.module.url(forResource: "RawCompIcon", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return
        }

        NSApplication.shared.applicationIconImage = image
    }
}
