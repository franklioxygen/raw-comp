import SwiftUI

struct ToneCurveEditorView: View {
    @Binding var points: ToneCurvePoints
    let showsCustomBadge: Bool

    private let handleRadius: CGFloat = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                let size = geometry.size
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.06))

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: size.height))
                        path.addLine(to: CGPoint(x: size.width, y: 0))
                    }
                    .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    Path { path in
                        let samples = 32
                        for index in 0...samples {
                            let t = Double(index) / Double(samples)
                            let y = points.outputValue(at: t)
                            let point = CGPoint(
                                x: CGFloat(t) * size.width,
                                y: (1 - CGFloat(y)) * size.height
                            )
                            if index == 0 {
                                path.move(to: point)
                            } else {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(Color.accentColor, lineWidth: 1.5)

                    curveHandle(index: 1, point: points.point1, size: size)
                    curveHandle(index: 2, point: points.point2, size: size)
                    curveHandle(index: 3, point: points.point3, size: size)
                }
            }
            .frame(height: 88)

            if showsCustomBadge {
                Text(L10n.string("tone_curve.custom_active"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func curveHandle(index: Int, point: CGPoint, size: CGSize) -> some View {
        let location = CGPoint(
            x: point.x * size.width,
            y: (1 - point.y) * size.height
        )

        Circle()
            .fill(Color.accentColor)
            .frame(width: handleRadius * 2, height: handleRadius * 2)
            .position(location)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updatePoint(index: index, location: value.location, size: size)
                    }
            )
    }

    private func updatePoint(index: Int, location: CGPoint, size: CGSize) {
        var next = points
        let normalized = CGPoint(
            x: min(max(location.x / size.width, 0), 1),
            y: min(max(1 - (location.y / size.height), 0), 1)
        )

        switch index {
        case 1:
            next.point1 = normalized
        case 2:
            next.point2 = normalized
        case 3:
            next.point3 = normalized
        default:
            return
        }

        next.clampMonotonic()
        points = next
    }
}
