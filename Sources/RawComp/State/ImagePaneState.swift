import CoreGraphics
import Foundation
import Observation

enum PaneLoadState: Equatable {
    case empty
    case loading
    case ready
    case failed(String)

    var label: String {
        switch self {
        case .empty:
            L10n.string("pane.state.empty")
        case .loading:
            L10n.string("pane.state.loading")
        case .ready:
            L10n.string("pane.state.ready")
        case let .failed(message):
            message
        }
    }
}

@Observable
@MainActor
final class ImagePaneState: Identifiable {
    let id = UUID()
    let slot: Int

    var loadedImage: LoadedImage?
    var renderedCGImage: CGImage?
    var loadState: PaneLoadState = .empty
    var viewport = ViewportState()

    var loadToken = UUID()
    var adjustmentRevision = 0

    init(slot: Int) {
        self.slot = slot
    }

    var title: String {
        loadedImage?.metadata.fileName ?? L10n.string("pane.title", slot + 1)
    }
}
