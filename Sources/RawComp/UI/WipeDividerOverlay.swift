import SwiftUI

struct WipeDividerOverlay: View {
    var store: WorkspaceStore

    var body: some View {
        GeometryReader { geometry in
            let position = store.adjustments.compareMode.wipePosition.clamped01
            let x = geometry.size.width * position

            ZStack(alignment: .leading) {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let next = (value.location.x / max(geometry.size.width, 1)).clamped01
                                store.setWipePosition(next)
                            }
                    )

                Rectangle()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 2)
                    .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 0)
                    .overlay(alignment: .top) {
                        Image(systemName: "line.3.vertical")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(6)
                            .background(.white.opacity(0.92), in: Circle())
                            .offset(y: 12)
                    }
                    .position(x: x, y: geometry.size.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let next = (value.location.x / max(geometry.size.width, 1)).clamped01
                                store.setWipePosition(next)
                            }
                    )
            }
        }
        .allowsHitTesting(true)
    }
}

private extension Double {
    var clamped01: Double {
        Swift.min(Swift.max(self, 0), 1)
    }
}
