import SwiftUI

struct ComparisonGridView: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(minimum: 260), spacing: 12, alignment: .top),
                        count: store.layout.columnCount
                    ),
                    alignment: .center,
                    spacing: 12
                ) {
                    ForEach(store.visiblePanes) { pane in
                        ImagePaneView(store: store, pane: pane)
                            .frame(
                                minHeight: idealPaneHeight(in: proxy.size, layout: store.layout)
                            )
                    }
                }
                .padding(12)
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func idealPaneHeight(in size: CGSize, layout: ComparisonLayout) -> CGFloat {
        let rowCount = CGFloat((layout.paneCount + layout.columnCount - 1) / layout.columnCount)
        let totalSpacing = max(0, rowCount - 1) * 12
        return max(260, (size.height - totalSpacing - 24) / rowCount)
    }
}
