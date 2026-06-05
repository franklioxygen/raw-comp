import SwiftUI

struct WorkspaceToolbar: View {
    var store: WorkspaceStore
    let onOpenAdvancedSettings: () -> Void
    @State private var showsExifFieldPicker = false
    @State private var showsTopInfoFieldPicker = false

    var body: some View {
        HStack(spacing: 8) {
            fileGroup
            toolbarDivider
            layoutGroup
            toolbarDivider
            viewGroup
            toolbarDivider
            zoomGroup
            toolbarDivider
            transformGroup

            Spacer(minLength: 12)

            appGroup
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Groups

    private var fileGroup: some View {
        HStack(spacing: 2) {
            Button {
                store.openImages()
            } label: {
                toolbarLabel("folder")
            }
            .buttonStyle(.plain)
            .help(L10n.string("toolbar.open_images"))
            .keyboardShortcut("o", modifiers: .command)

            sessionToolbarMenu

            Button(action: store.exportComparisonToFile) {
                toolbarLabel("square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .help(L10n.string("toolbar.export_comparison"))
        }
    }

    private var layoutGroup: some View {
        HStack(spacing: 2) {
            ForEach(ComparisonLayout.allCases) { layout in
                Button {
                    store.layout = layout
                } label: {
                    toolbarLabel(layout.menuIconSystemName, isActive: store.layout == layout)
                }
                .buttonStyle(.plain)
                .help(layout.menuLabel)
            }
        }
    }

    private var viewGroup: some View {
        HStack(spacing: 2) {
            Button(action: toggleLinkMode) {
                linkModeLabel
            }
            .buttonStyle(.plain)
            .help(store.linkMode == .synced ? L10n.string("toolbar.linked") : L10n.string("toolbar.unlinked"))

            Button(action: toggleHighlightRegion) {
                toolbarLabel(
                    store.highlightRect == nil ? "viewfinder" : "viewfinder.circle.fill",
                    isActive: store.highlightRect != nil
                )
            }
            .buttonStyle(.plain)
            .disabled(highlightDisabled)
            .opacity(highlightDisabled ? 0.4 : 1)
            .help(store.highlightRect == nil ? L10n.string("toolbar.mark_region") : L10n.string("toolbar.remove_region"))

            Button {
                showsExifFieldPicker.toggle()
            } label: {
                toolbarLabel("info.circle", isActive: store.showExifOverlay)
            }
            .buttonStyle(.plain)
            .help(L10n.string("inspector.exif"))
            .popover(isPresented: $showsExifFieldPicker, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                ExifFieldPickerPopover(store: store)
            }

            Button {
                showsTopInfoFieldPicker.toggle()
            } label: {
                toolbarLabel("rectangle.tophalf.inset.filled", isActive: store.showTopInfoBar)
            }
            .buttonStyle(.plain)
            .help(L10n.string("top_info.title"))
            .popover(isPresented: $showsTopInfoFieldPicker, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                TopInfoFieldPickerPopover(store: store)
            }
        }
    }

    private var zoomGroup: some View {
        HStack(spacing: 2) {
            Button(action: store.zoomOut) {
                toolbarLabel("minus.magnifyingglass")
            }
            .buttonStyle(.plain)
            .help(L10n.string("toolbar.zoom_out"))

            Button(action: store.zoomIn) {
                toolbarLabel("plus.magnifyingglass")
            }
            .buttonStyle(.plain)
            .help(L10n.string("toolbar.zoom_in"))

            Button(action: store.fitToWindow) {
                toolbarLabel("arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.plain)
            .help(L10n.string("toolbar.fit_to_window"))

            Button(action: store.actualPixels) {
                ActualPixelsGlyph()
                    .frame(width: 15, height: 15)
                    .modifier(ToolbarSurface())
            }
            .buttonStyle(.plain)
            .help(L10n.string("toolbar.actual_pixels"))
        }
    }

    private var transformGroup: some View {
        HStack(spacing: 2) {
            Button(action: store.rotateLeft) {
                toolbarLabel("rotate.left")
            }
            .buttonStyle(.plain)
            .help(L10n.string("toolbar.rotate_left"))

            Button(action: store.rotateRight) {
                toolbarLabel("rotate.right")
            }
            .buttonStyle(.plain)
            .help(L10n.string("toolbar.rotate_right"))
        }
    }

    private var appGroup: some View {
        HStack(spacing: 2) {
            Button(action: onOpenAdvancedSettings) {
                toolbarLabel("gearshape")
            }
            .buttonStyle(.plain)
            .help(L10n.string("toolbar.advanced_settings"))

            Button {
                store.showInspector.toggle()
            } label: {
                toolbarLabel("sidebar.right", isActive: store.showInspector)
            }
            .buttonStyle(.plain)
            .help(store.showInspector ? L10n.string("toolbar.hide_inspector") : L10n.string("toolbar.show_inspector"))
        }
    }

    private var sessionToolbarMenu: some View {
        Menu {
            Button(L10n.string("toolbar.open_session"), action: store.openSessionFromFile)
            Button(L10n.string("toolbar.save_session"), action: store.saveSessionToFile)

            if store.recentSessions.first != nil {
                Button(L10n.string("toolbar.open_recent_session"), action: store.openMostRecentSession)
            }

            if !store.recentSessions.isEmpty {
                Divider()
                ForEach(store.recentSessions, id: \.path) { url in
                    Button(url.lastPathComponent) {
                        store.openRecentSession(at: url)
                    }
                }
                Divider()
                Button(L10n.string("toolbar.clear_recent_sessions"), role: .destructive) {
                    store.clearRecentSessions()
                }
            }
        } label: {
            toolbarLabel("clock.arrow.circlepath")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help(L10n.string("toolbar.session_menu"))
    }

    // MARK: - Helpers

    private var highlightDisabled: Bool {
        store.activePane?.loadedImage == nil && store.highlightRect == nil
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

    private func toolbarLabel(_ systemName: String, isActive: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .modifier(ToolbarSurface(isActive: isActive))
    }

    private var linkModeLabel: some View {
        ZStack {
            Image(systemName: "link")
                .font(.system(size: 15, weight: .medium))

            if store.linkMode == .unlinked {
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 1.6, height: 19)
                    .rotationEffect(.degrees(45))
            }
        }
        .modifier(ToolbarSurface(isActive: store.linkMode == .synced))
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 18)
    }
}

private struct ExifFieldPickerPopover: View {
    var store: WorkspaceStore

    var body: some View {
        FieldPickerPopover(
            title: L10n.string("inspector.exif"),
            fields: store.exifOverlayFields,
            hasSelection: store.showExifOverlay,
            canSelectAll: store.canSelectAllExifOverlayFields,
            onSelectAll: store.selectAllExifOverlayFields,
            onClear: store.clearExifOverlayFields,
            label: \.label,
            isSelected: { store.isExifOverlayFieldSelected($0) },
            isEnabled: { field in
                store.isExifOverlayFieldSelected(field) || store.isExifOverlayFieldAvailable(field)
            },
            onToggle: { field in
                store.setExifOverlayField(field, isSelected: !store.isExifOverlayFieldSelected(field))
            }
        )
    }
}

private struct TopInfoFieldPickerPopover: View {
    var store: WorkspaceStore

    var body: some View {
        FieldPickerPopover(
            title: L10n.string("top_info.title"),
            fields: store.topInfoOverlayFields,
            hasSelection: store.showTopInfoBar,
            canSelectAll: store.canSelectAllTopInfoOverlayFields,
            onSelectAll: store.selectAllTopInfoOverlayFields,
            onClear: store.clearTopInfoOverlayFields,
            label: \.label,
            isSelected: { store.isTopInfoOverlayFieldSelected($0) },
            isEnabled: { _ in true },
            onToggle: { field in
                store.setTopInfoOverlayField(field, isSelected: !store.isTopInfoOverlayFieldSelected(field))
            }
        )
    }
}

private struct FieldPickerPopover<Field: Identifiable>: View {
    let title: String
    let fields: [Field]
    let hasSelection: Bool
    let canSelectAll: Bool
    let onSelectAll: () -> Void
    let onClear: () -> Void
    let label: KeyPath<Field, String>
    let isSelected: (Field) -> Bool
    let isEnabled: (Field) -> Bool
    let onToggle: (Field) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.headline)

                Spacer(minLength: 8)

                Button(L10n.string("picker.all"), action: onSelectAll)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .disabled(!canSelectAll)

                Button(L10n.string("picker.clear"), action: onClear)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .disabled(!hasSelection)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(fields) { field in
                    PickerCheckboxRow(
                        title: field[keyPath: label],
                        isSelected: isSelected(field),
                        isEnabled: isEnabled(field)
                    ) {
                        onToggle(field)
                    }
                }
            }
        }
        .padding(14)
        .frame(minWidth: 240, idealWidth: 280)
    }
}

private struct PickerCheckboxRow: View {
    let title: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(isEnabled ? 0.7 : 0.35))

                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.08 : 0))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.65)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct ToolbarSurface: ViewModifier {
    var isActive: Bool = false

    func body(content: Content) -> some View {
        ToolbarSurfaceBody(isActive: isActive) { content }
    }

    private struct ToolbarSurfaceBody<C: View>: View {
        let isActive: Bool
        @ViewBuilder var content: () -> C
        @State private var hovering = false

        var body: some View {
            content()
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(background)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
                .animation(.easeOut(duration: 0.12), value: isActive)
        }

        private var background: Color {
            if isActive {
                return Color.accentColor.opacity(hovering ? 0.26 : 0.18)
            }
            return hovering ? Color.primary.opacity(0.09) : Color.clear
        }
    }
}

private struct ActualPixelsGlyph: View {
    var body: some View {
        GeometryReader { geometry in
            let inset = geometry.size.width * 0.12
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
                    .frame(width: geometry.size.width * 0.2, height: geometry.size.height * 0.2)
            }
        }
    }
}
