import CoreGraphics
import Foundation

enum ToneCurveLUT {
    static func ciPoints(for preset: ToneCurvePreset) -> (
        CGPoint, CGPoint, CGPoint, CGPoint, CGPoint
    ) {
        switch preset {
        case .linear:
            return (
                CGPoint(x: 0, y: 0),
                CGPoint(x: 0.25, y: 0.25),
                CGPoint(x: 0.5, y: 0.5),
                CGPoint(x: 0.75, y: 0.75),
                CGPoint(x: 1, y: 1)
            )
        case .softContrast:
            return (
                CGPoint(x: 0, y: 0),
                CGPoint(x: 0.25, y: 0.22),
                CGPoint(x: 0.5, y: 0.5),
                CGPoint(x: 0.75, y: 0.78),
                CGPoint(x: 1, y: 1)
            )
        case .mediumContrast:
            return (
                CGPoint(x: 0, y: 0),
                CGPoint(x: 0.25, y: 0.18),
                CGPoint(x: 0.5, y: 0.5),
                CGPoint(x: 0.75, y: 0.82),
                CGPoint(x: 1, y: 1)
            )
        case .strongContrast:
            return (
                CGPoint(x: 0, y: 0),
                CGPoint(x: 0.25, y: 0.12),
                CGPoint(x: 0.5, y: 0.5),
                CGPoint(x: 0.75, y: 0.88),
                CGPoint(x: 1, y: 1)
            )
        }
    }

    static func ciPoints(from points: ToneCurvePoints) -> (
        CGPoint, CGPoint, CGPoint, CGPoint, CGPoint
    ) {
        points.ciControlPoints
    }
}
