import SwiftUI

struct WorkspaceToolbar: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        HStack(spacing: 12) {
            Button("Open", systemImage: "folder") {
                store.openImages()
            }
            .keyboardShortcut("o", modifiers: .command)

            Picker("Layout", selection: layoutBinding) {
                ForEach(ComparisonLayout.allCases) { layout in
                    Text(layout.title).tag(layout)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)

            Picker("Link", selection: linkBinding) {
                ForEach(LinkMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Toggle("Highlight", isOn: highlightBinding)
                .toggleStyle(.button)

            Button("Mark Region", systemImage: "viewfinder.circle") {
                store.captureHighlightFromActivePane()
            }
            .disabled(store.activePane?.loadedImage == nil)

            Button("", systemImage: "trash") {
                store.clearHighlight()
            }
            .help("Clear highlight")

            Divider()
                .frame(height: 18)

            Button("", systemImage: "minus.magnifyingglass") {
                store.zoomOut()
            }
            .help("Zoom out")

            Button("", systemImage: "plus.magnifyingglass") {
                store.zoomIn()
            }
            .help("Zoom in")

            Button("Fit") {
                store.fitToWindow()
            }

            Button("100%") {
                store.actualPixels()
            }

            Button("", systemImage: "rotate.left") {
                store.rotateLeft()
            }
            .help("Rotate left")

            Button("", systemImage: "rotate.right") {
                store.rotateRight()
            }
            .help("Rotate right")

            Spacer()

            Toggle("Inspector", isOn: inspectorBinding)
                .toggleStyle(.button)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var layoutBinding: Binding<ComparisonLayout> {
        Binding(
            get: { store.layout },
            set: { store.layout = $0 }
        )
    }

    private var linkBinding: Binding<LinkMode> {
        Binding(
            get: { store.linkMode },
            set: { store.linkMode = $0 }
        )
    }

    private var highlightBinding: Binding<Bool> {
        Binding(
            get: { store.showHighlight },
            set: { store.showHighlight = $0 }
        )
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { store.showInspector },
            set: { store.showInspector = $0 }
        )
    }
}
