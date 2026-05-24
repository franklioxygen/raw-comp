import Foundation
import CoreGraphics

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

@MainActor
final class ImagePaneState: ObservableObject, Identifiable {
    let id = UUID()
    let slot: Int

    @Published var loadedImage: LoadedImage?
    @Published var renderedCGImage: CGImage?
    @Published var loadState: PaneLoadState = .empty
    @Published var viewport = ViewportState()

    var loadToken = UUID()
    var adjustmentRevision = 0

    init(slot: Int) {
        self.slot = slot
    }

    var title: String {
        loadedImage?.metadata.fileName ?? L10n.string("pane.title", slot + 1)
    }
}
