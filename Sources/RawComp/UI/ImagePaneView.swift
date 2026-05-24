import SwiftUI
import UniformTypeIdentifiers

struct ImagePaneView: View {
    @ObservedObject var store: WorkspaceStore
    @ObservedObject var pane: ImagePaneState

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let loadedImage = pane.loadedImage {
                    ImageCanvasView(
                        loadedImage: loadedImage,
                        displayCGImage: pane.renderedCGImage ?? loadedImage.cgImage,
                        viewport: pane.viewport,
                        highlightRect: store.highlightRect,
                        onViewportChange: { store.updateViewport(from: pane.id, viewport: $0) },
                        onSelect: { store.selectPane(pane.id) }
                    )
                    .overlay(alignment: .bottomLeading) {
                        if store.showExifOverlay, let summary = loadedImage.metadata.basicExifSummary {
                            exifOverlay(summary)
                        }
                    }
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .black))
            .overlay(alignment: .topLeading) {
                if store.showTopInfoBar {
                    topInfoOverlay
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(
                    store.isSelected(pane) ? Color.accentColor : Color.secondary.opacity(0.25),
                    lineWidth: store.isSelected(pane) ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectPane(pane.id)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            store.loadDroppedItemProviders(providers, into: pane.id)
        }
    }

    private var subtitleText: String {
        guard let metadata = pane.loadedImage?.metadata else {
            return L10n.string("pane.drop_or_load")
        }

        return metadata.dimensionsText
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text(L10n.string("pane.title", pane.slot + 1))
                .font(.title3.weight(.semibold))

            L10n.text("pane.empty_description")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 260)

            Button(L10n.string("pane.load_image"), systemImage: "plus") {
                store.openImages(replacing: pane.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(Color(nsColor: .black))
    }

    private var topInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(pane.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(subtitleText)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.78))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.72),
                    Color.black.opacity(0.38),
                    Color.black.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .shadow(color: .black.opacity(0.55), radius: 8, y: 2)
        )
    }

    private func exifOverlay(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.72),
                        Color.black.opacity(0.38),
                        Color.black.opacity(0.0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .shadow(color: .black.opacity(0.55), radius: 8, y: -2)
            )
    }
}
