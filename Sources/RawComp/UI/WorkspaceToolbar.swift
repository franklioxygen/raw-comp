import SwiftUI

struct WorkspaceToolbar: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                store.openImages()
            }) {
                toolbarStandaloneIcon("folder")
            }
            .help("Open images")
            .keyboardShortcut("o", modifiers: .command)
            .buttonStyle(.plain)

            Menu {
                ForEach(ComparisonLayout.allCases) { layout in
                    Button {
                        store.layout = layout
                    } label: {
                        Label {
                            EmptyView()
                        } icon: {
                            Image(systemName: layout.menuIconSystemName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: store.layout.menuIconSystemName)
                        .frame(width: 16, height: 16)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .frame(width: 72, height: toolbarHeight)
                .toolbarButtonSurface()
            }
            .menuStyle(.button)
            .buttonStyle(.plain)

            Button(action: toggleLinkMode) {
                linkModeIcon
            }
            .help(store.linkMode == .synced ? "Linked panes are synced" : "Panes move independently")
            .buttonStyle(.plain)

            Button(action: toggleHighlightRegion) {
                toolbarStandaloneIcon(
                    store.highlightRect == nil ? "viewfinder.circle" : "xmark.circle",
                    isActive: store.highlightRect != nil
                )
            }
            .disabled(store.activePane?.loadedImage == nil && store.highlightRect == nil)
            .opacity(store.activePane?.loadedImage == nil && store.highlightRect == nil ? 0.45 : 1)
            .help(store.highlightRect == nil ? "Mark synchronized region" : "Remove synchronized region")
            .buttonStyle(.plain)

            Button(action: {
                store.showExifOverlay.toggle()
            }) {
                toolbarStandaloneIcon("info.circle", isActive: store.showExifOverlay)
            }
            .help(store.showExifOverlay ? "Hide EXIF overlay" : "Show EXIF overlay")
            .buttonStyle(.plain)

            Button(action: {
                store.showTopInfoBar.toggle()
            }) {
                toolbarStandaloneIcon("rectangle.tophalf.inset.filled", isActive: store.showTopInfoBar)
            }
            .help(store.showTopInfoBar ? "Hide top info bar" : "Show top info bar")
            .buttonStyle(.plain)

            Divider()
                .frame(height: 18)

            toolbarGroup {
                Button(action: store.zoomOut) {
                    toolbarIcon("minus.magnifyingglass")
                }
                .help("Zoom out")
                .buttonStyle(.plain)

                Button(action: store.zoomIn) {
                    toolbarIcon("plus.magnifyingglass")
                }
                .help("Zoom in")
                .buttonStyle(.plain)
            }

            toolbarGroup {
                Button(action: store.fitToWindow) {
                    toolbarIcon("arrow.up.left.and.arrow.down.right")
                }
                .help("Fit to window")
                .buttonStyle(.plain)

                Button(action: store.actualPixels) {
                    toolbarCustomIcon {
                        ActualPixelsGlyph()
                    }
                }
                .help("Actual pixels")
                .buttonStyle(.plain)
            }

            toolbarGroup {
                Button(action: store.rotateLeft) {
                    toolbarIcon("rotate.left")
                }
                .help("Rotate left")
                .buttonStyle(.plain)

                Button(action: store.rotateRight) {
                    toolbarIcon("rotate.right")
                }
                .help("Rotate right")
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: {
                store.showInspector.toggle()
            }) {
                toolbarStandaloneIcon("sidebar.right", isActive: store.showInspector)
            }
            .help(store.showInspector ? "Hide inspector" : "Show inspector")
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func toggleLinkMode() {
        store.linkMode = store.linkMode == .synced ? .unlinked : .synced
    }

    private func toggleHighlightRegion() {
        if store.highlightRect == nil {
            store.captureHighlightFromActivePane()
        } else {
            store.clearHighlight()
        }
    }

    private var toolbarHeight: CGFloat {
        34
    }

    private var linkModeIcon: some View {
        ZStack {
            Image(systemName: "link")
                .frame(width: 18, height: 18)

            if store.linkMode == .unlinked {
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2, height: 20)
                    .rotationEffect(.degrees(45))
            }
        }
        .frame(width: 44, height: toolbarHeight)
        .toolbarButtonSurface(isActive: store.linkMode == .synced)
    }

    private func toolbarButtonLabel(_ title: String, systemName: String, isActive: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .frame(width: 18, height: 18)
            Text(title)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 14)
        .frame(height: toolbarHeight)
        .toolbarButtonSurface(isActive: isActive)
    }

    private func toolbarStandaloneIcon(_ systemName: String, isActive: Bool = false) -> some View {
        Image(systemName: systemName)
            .frame(width: 18, height: 18)
            .frame(width: 44, height: toolbarHeight)
            .toolbarButtonSurface(isActive: isActive)
    }

    private func toolbarGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0, content: content)
            .frame(width: 88, height: toolbarHeight)
            .toolbarButtonSurface()
            .overlay {
                Rectangle()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(width: 1, height: 18)
            }
    }

    private func toolbarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .frame(width: 18, height: 18)
            .frame(width: 44, height: toolbarHeight)
            .contentShape(Rectangle())
    }

    private func toolbarCustomIcon<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 18, height: 18)
            .frame(width: 44, height: toolbarHeight)
            .contentShape(Rectangle())
    }

}

private struct ActualPixelsGlyph: View {
    var body: some View {
        GeometryReader { geometry in
            let inset = geometry.size.width * 0.18
            let rect = CGRect(
                x: inset,
                y: inset,
                width: geometry.size.width - (inset * 2),
                height: geometry.size.height - (inset * 2)
            )

            ZStack {
                Path { path in
                    path.addRect(rect)
                }
                .stroke(style: StrokeStyle(lineWidth: 1.5))

                Circle()
                    .fill(Color.primary)
                    .frame(width: geometry.size.width * 0.18, height: geometry.size.height * 0.18)
            }
        }
    }
}

private extension View {
    func toolbarButtonSurface(isActive: Bool = false) -> some View {
        foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
            )
    }
}
