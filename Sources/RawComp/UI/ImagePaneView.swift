import SwiftUI
import UniformTypeIdentifiers

struct ImagePaneView: View {
    @ObservedObject var store: WorkspaceStore
    @ObservedObject var pane: ImagePaneState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pane.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                statusBadge
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            Group {
                if let loadedImage = pane.loadedImage {
                    ImageCanvasView(
                        loadedImage: loadedImage,
                        displayCGImage: pane.renderedCGImage ?? loadedImage.cgImage,
                        viewport: pane.viewport,
                        highlightRect: store.showHighlight ? store.highlightRect : nil,
                        onViewportChange: { store.updateViewport(from: pane.id, viewport: $0) },
                        onSelect: { store.selectPane(pane.id) }
                    )
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .black))
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    store.isSelected(pane) ? Color.accentColor : Color.secondary.opacity(0.25),
                    lineWidth: store.isSelected(pane) ? 2 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            store.selectPane(pane.id)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            store.loadDroppedItemProviders(providers, into: pane.id)
        }
    }

    private var subtitleText: String {
        guard let metadata = pane.loadedImage?.metadata else {
            return "Drop a file or load one into this pane."
        }

        return metadata.dimensionsText
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch pane.loadState {
        case .empty:
            badge("Empty", color: .secondary)
        case .loading:
            badge("Loading", color: .orange)
        case .ready:
            if pane.loadedImage?.isPreview == true {
                badge("Preview", color: .yellow)
            } else {
                badge("Ready", color: .green)
            }
        case let .failed(message):
            badge(message, color: .red)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text("Pane \(pane.slot + 1)")
                .font(.title3.weight(.semibold))

            Text("Load a standard image or a RAW file to start comparing.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 260)

            Button("Load Image", systemImage: "plus") {
                store.openImages(replacing: pane.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(Color(nsColor: .black))
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
