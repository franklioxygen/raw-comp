import SwiftUI
import UniformTypeIdentifiers

struct ImagePaneView: View {
    var store: WorkspaceStore
    var pane: ImagePaneState

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let loadedImage = pane.loadedImage {
                    ImageCanvasView(
                        loadedImage: loadedImage,
                        displayCGImage: store.displayCGImage(for: pane) ?? loadedImage.cgImage,
                        viewport: pane.viewport,
                        highlightRect: store.highlightRect,
                        showCropOverlay: store.showsCropOverlay(for: pane),
                        cropRectNormalized: store.cropRectNormalized,
                        allowsCropEditing: store.allowsCropEditing(for: pane),
                        locksCropAspect: store.adjustments.geometry.aspectLock,
                        onViewportChange: { store.updateViewport(from: pane.id, viewport: $0) },
                        onSelect: { store.selectPane(pane.id) },
                        onCropRectChange: { rect in
                            store.setCropRectNormalized(rect)
                        },
                        onImageCursorMove: { point in
                            Task { @MainActor in
                                store.updatePixelReadout(normalizedPoint: point, from: pane.id)
                            }
                        }
                    )
                    .overlay(alignment: .bottomLeading) {
                        if store.showExifOverlay, let summary = store.exifSummary(for: loadedImage.metadata) {
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
                if store.showTopInfoBar, !store.topInfoLines(for: pane).isEmpty {
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
        let lines = store.topInfoLines(for: pane)
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(index == 0 ? .headline : .caption)
                    .foregroundStyle(index == 0 ? Color.white : Color.white.opacity(0.78))
                    .lineLimit(1)
            }
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
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
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
