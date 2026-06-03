import CoreGraphics
import Foundation

struct ToneCurvePoints: Equatable, Sendable, Codable {
    var point1: CGPoint
    var point2: CGPoint
    var point3: CGPoint

    static let linear = ToneCurvePoints(
        point1: CGPoint(x: 0.25, y: 0.25),
        point2: CGPoint(x: 0.5, y: 0.5),
        point3: CGPoint(x: 0.75, y: 0.75)
    )

    init(point1: CGPoint, point2: CGPoint, point3: CGPoint) {
        self.point1 = point1
        self.point2 = point2
        self.point3 = point3
        clampMonotonic()
    }

    init(preset: ToneCurvePreset) {
        let points = ToneCurveLUT.ciPoints(for: preset)
        point1 = points.1
        point2 = points.2
        point3 = points.3
    }

    var isLinear: Bool {
        self == .linear
    }

    var ciControlPoints: (CGPoint, CGPoint, CGPoint, CGPoint, CGPoint) {
        (
            CGPoint(x: 0, y: 0),
            point1,
            point2,
            point3,
            CGPoint(x: 1, y: 1)
        )
    }

    mutating func clampMonotonic() {
        let minGap: CGFloat = 0.04

        point1.x = clamp(point1.x, min: minGap, max: 1 - 3 * minGap)
        point2.x = clamp(point2.x, min: point1.x + minGap, max: 1 - 2 * minGap)
        point3.x = clamp(point3.x, min: point2.x + minGap, max: 1 - minGap)

        point1.y = clamp(point1.y, min: 0, max: 1)
        point2.y = clamp(point2.y, min: point1.y, max: 1)
        point3.y = clamp(point3.y, min: point2.y, max: 1)
    }

    func outputValue(at input: Double) -> Double {
        let controls = ciControlPoints
        let xs = [
            Double(controls.0.x),
            Double(controls.1.x),
            Double(controls.2.x),
            Double(controls.3.x),
            Double(controls.4.x),
        ]
        let ys = [
            Double(controls.0.y),
            Double(controls.1.y),
            Double(controls.2.y),
            Double(controls.3.y),
            Double(controls.4.y),
        ]

        let t = Swift.min(Swift.max(input, 0), 1)
        for index in 0..<(xs.count - 1) {
            let x0 = xs[index]
            let x1 = xs[index + 1]
            if t <= x1 || index == xs.count - 2 {
                let span = max(x1 - x0, 0.0001)
                let fraction = (t - x0) / span
                let y0 = ys[index]
                let y1 = ys[index + 1]
                return y0 + (y1 - y0) * fraction
            }
        }
        return t
    }

    private enum CodingKeys: String, CodingKey {
        case point1X
        case point1Y
        case point2X
        case point2Y
        case point3X
        case point3Y
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        point1 = CGPoint(
            x: try container.decode(CGFloat.self, forKey: .point1X),
            y: try container.decode(CGFloat.self, forKey: .point1Y)
        )
        point2 = CGPoint(
            x: try container.decode(CGFloat.self, forKey: .point2X),
            y: try container.decode(CGFloat.self, forKey: .point2Y)
        )
        point3 = CGPoint(
            x: try container.decode(CGFloat.self, forKey: .point3X),
            y: try container.decode(CGFloat.self, forKey: .point3Y)
        )
        clampMonotonic()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(point1.x, forKey: .point1X)
        try container.encode(point1.y, forKey: .point1Y)
        try container.encode(point2.x, forKey: .point2X)
        try container.encode(point2.y, forKey: .point2Y)
        try container.encode(point3.x, forKey: .point3X)
        try container.encode(point3.y, forKey: .point3Y)
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
    }
}
