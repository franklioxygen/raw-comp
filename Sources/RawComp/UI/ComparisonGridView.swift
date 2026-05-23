import SwiftUI

struct ComparisonGridView: View {
    @ObservedObject var store: WorkspaceStore

    private let paneSpacing: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(minimum: 260), spacing: paneSpacing, alignment: .top),
                        count: store.layout.columnCount
                    ),
                    alignment: .center,
                    spacing: paneSpacing
                ) {
                    ForEach(store.visiblePanes) { pane in
                        ImagePaneView(store: store, pane: pane)
                            .frame(
                                minHeight: idealPaneHeight(in: proxy.size, layout: store.layout)
                            )
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func idealPaneHeight(in size: CGSize, layout: ComparisonLayout) -> CGFloat {
        let rowCount = CGFloat((layout.paneCount + layout.columnCount - 1) / layout.columnCount)
        let totalSpacing = max(0, rowCount - 1) * paneSpacing
        return max(260, (size.height - totalSpacing) / rowCount)
    }
}
