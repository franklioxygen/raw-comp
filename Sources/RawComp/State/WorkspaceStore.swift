import AppKit
import Foundation
import UniformTypeIdentifiers

enum LinkMode: String, CaseIterable, Identifiable {
    case unlinked = "Free"
    case synced = "Synced"

    var id: String { rawValue }
}

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var layout: ComparisonLayout = .two {
        didSet {
            if !visiblePanes.contains(where: { $0.id == activePaneID }) {
                activePaneID = visiblePanes.first?.id
            }
        }
    }
    @Published var linkMode: LinkMode = .synced
    @Published var showHighlight = true
    @Published var highlightRect: CGRect?
    @Published var showInspector = true
    @Published var adjustments = ComparisonAdjustments() {
        didSet {
            guard adjustments != oldValue else {
                return
            }

            scheduleAdjustmentRefresh()
        }
    }
    @Published var statusMessage = "Open images to compare 2, 3, 4, or 6 panes."

    let panes: [ImagePaneState]

    private let imageLoader = ImageLoader.shared
    private let imageAdjustmentRenderer = ImageAdjustmentRenderer.shared
    private var activePaneID: UUID?
    private var adjustmentDispatchTask: Task<Void, Never>?

    init() {
        panes = (0..<6).map { ImagePaneState(slot: $0) }
        activePaneID = panes.first?.id
    }

    var visiblePanes: [ImagePaneState] {
        Array(panes.prefix(layout.paneCount))
    }

    var activePane: ImagePaneState? {
        if let activePaneID {
            return panes.first(where: { $0.id == activePaneID })
        }

        return visiblePanes.first
    }

    func isSelected(_ pane: ImagePaneState) -> Bool {
        pane.id == activePane?.id
    }

    func selectPane(_ paneID: UUID) {
        activePaneID = paneID
    }

    func openImages(replacing paneID: UUID? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = paneID == nil
        panel.message = "Choose standard images or RAW files to compare."

        if panel.runModal() == .OK {
            importImages(urls: panel.urls, replacing: paneID)
        }
    }

    func importImages(urls: [URL], replacing paneID: UUID? = nil) {
        let normalizedURLs = urls.filter { !$0.pathExtension.isEmpty || $0.hasDirectoryPath == false }
        guard !normalizedURLs.isEmpty else {
            statusMessage = "No loadable files were selected."
            return
        }

        if let paneID, let pane = panes.first(where: { $0.id == paneID }), let firstURL = normalizedURLs.first {
            load(url: firstURL, into: pane)
            return
        }

        if normalizedURLs.count == 1, let activePane, visiblePanes.contains(where: { $0.id == activePane.id }) {
            load(url: normalizedURLs[0], into: activePane)
            return
        }

        let targets = Array(visiblePanes.prefix(normalizedURLs.count))
        for (pane, url) in zip(targets, normalizedURLs) {
            load(url: url, into: pane)
        }

        if normalizedURLs.count > targets.count {
            statusMessage = "Loaded the first \(targets.count) files for the current \(layout.paneCount)-pane layout."
        }
    }

    func loadDroppedItemProviders(_ providers: [NSItemProvider], into paneID: UUID) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] data, _ in
            guard
                let self,
                let data,
                let url = URL(dataRepresentation: data, relativeTo: nil)
            else {
                return
            }

            Task { @MainActor in
                self.importImages(urls: [url], replacing: paneID)
            }
        }

        return true
    }

    func updateViewport(from paneID: UUID, viewport: ViewportState) {
        guard let sourcePane = panes.first(where: { $0.id == paneID }) else {
            return
        }

        let clamped = viewport.clamped()
        if sourcePane.viewport != clamped {
            sourcePane.viewport = clamped
        }

        guard linkMode == .synced else {
            return
        }

        for pane in visiblePanes where pane.id != paneID && pane.loadedImage != nil {
            pane.viewport = clamped
        }
    }

    func zoomIn() {
        mutateActiveViewport { viewport in
            viewport.zoomMode = .manual
            viewport.zoomScale *= 1.25
        }
    }

    func zoomOut() {
        mutateActiveViewport { viewport in
            viewport.zoomMode = .manual
            viewport.zoomScale /= 1.25
        }
    }

    func fitToWindow() {
        mutateActiveViewport { viewport in
            viewport.zoomMode = .fit
        }
    }

    func actualPixels() {
        mutateActiveViewport { viewport in
            viewport.zoomMode = .actual
            viewport.zoomScale = 1.0
        }
    }

    func rotateLeft() {
        mutateActiveViewport { viewport in
            viewport.rotationQuarterTurns -= 1
        }
    }

    func rotateRight() {
        mutateActiveViewport { viewport in
            viewport.rotationQuarterTurns += 1
        }
    }

    func captureHighlightFromActivePane() {
        guard let activePane else {
            return
        }

        let rect = activePane.viewport.visibleRectNormalized.clampedUnit()
        guard rect.width > 0, rect.height > 0 else {
            statusMessage = "No visible region is available to highlight yet."
            return
        }

        highlightRect = rect
        showHighlight = true
        statusMessage = "Captured a synchronized highlight region from \(activePane.title)."
    }

    func clearHighlight() {
        highlightRect = nil
        statusMessage = "Cleared the synchronized highlight region."
    }

    func resetAdjustments() {
        adjustments = .neutral
    }

    private func load(url: URL, into pane: ImagePaneState) {
        pane.loadToken = UUID()
        let loadToken = pane.loadToken
        pane.loadState = .loading
        pane.loadedImage = nil
        pane.renderedCGImage = nil
        pane.viewport = ViewportState()
        pane.adjustmentRevision += 1
        activePaneID = pane.id
        statusMessage = "Loading \(url.lastPathComponent)..."

        Task {
            do {
                let image = try await imageLoader.loadImage(from: url)
                await MainActor.run {
                    guard pane.loadToken == loadToken else {
                        return
                    }

                    pane.loadedImage = image
                    pane.renderedCGImage = image.cgImage
                    pane.loadState = .ready
                    pane.viewport = ViewportState()
                    statusMessage = image.isPreview
                        ? "Loaded \(image.metadata.fileName) using a preview pipeline."
                        : "Loaded \(image.metadata.fileName)."
                    applyCurrentAdjustments(to: pane, loadedImage: image)
                }
            } catch {
                await MainActor.run {
                    guard pane.loadToken == loadToken else {
                        return
                    }

                    pane.loadState = .failed(error.localizedDescription)
                    pane.renderedCGImage = nil
                    statusMessage = error.localizedDescription
                }
            }
        }
    }

    private func mutateActiveViewport(_ transform: (inout ViewportState) -> Void) {
        guard let activePane else {
            return
        }

        var next = activePane.viewport
        transform(&next)
        next = next.clamped()
        activePane.viewport = next

        guard linkMode == .synced else {
            return
        }

        for pane in visiblePanes where pane.id != activePane.id && pane.loadedImage != nil {
            pane.viewport = next
        }
    }

    private func scheduleAdjustmentRefresh() {
        adjustmentDispatchTask?.cancel()
        adjustmentDispatchTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 90_000_000)
            } catch {
                return
            }

            self?.applyAdjustmentsToLoadedPanes()
        }
    }

    private func applyAdjustmentsToLoadedPanes() {
        for pane in panes {
            guard let loadedImage = pane.loadedImage else {
                continue
            }

            applyCurrentAdjustments(to: pane, loadedImage: loadedImage)
        }
    }

    private func applyCurrentAdjustments(to pane: ImagePaneState, loadedImage: LoadedImage) {
        pane.adjustmentRevision += 1
        let revision = pane.adjustmentRevision
        let currentAdjustments = adjustments

        if currentAdjustments.isNeutral {
            pane.renderedCGImage = loadedImage.cgImage
            return
        }

        Task {
            let renderedImage = await imageAdjustmentRenderer.render(loadedImage, adjustments: currentAdjustments)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard
                    pane.adjustmentRevision == revision,
                    pane.loadedImage?.url == loadedImage.url
                else {
                    return
                }

                pane.renderedCGImage = renderedImage ?? loadedImage.cgImage
            }
        }
    }
}
