import SwiftUI

struct ToneCurvePreviewView: View {
    let points: ToneCurvePoints

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.06))

                Path { path in
                    let samples = 24
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

                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height))
                    path.addLine(to: CGPoint(x: size.width, y: 0))
                }
                .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .frame(height: 56)
    }
}
