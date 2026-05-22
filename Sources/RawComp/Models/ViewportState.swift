import CoreGraphics

enum ZoomMode: String, Equatable, Sendable {
    case fit
    case actual
    case manual
}

struct ViewportState: Equatable, Sendable {
    var zoomMode: ZoomMode = .fit
    var zoomScale: CGFloat = 1.0
    var normalizedCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var visibleRectNormalized: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    var rotationQuarterTurns: Int = 0

    func clamped() -> ViewportState {
        ViewportState(
            zoomMode: zoomMode,
            zoomScale: min(max(zoomScale, 0.05), 20.0),
            normalizedCenter: normalizedCenter.clampedUnit(),
            visibleRectNormalized: visibleRectNormalized.clampedUnit(),
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
}

private extension CGPoint {
    func clampedUnit() -> CGPoint {
        CGPoint(
            x: min(max(x, 0), 1),
            y: min(max(y, 0), 1)
        )
    }
}

extension CGRect {
    func clampedUnit() -> CGRect {
        let minX = min(max(origin.x, 0), 1)
        let minY = min(max(origin.y, 0), 1)
        let maxX = min(max(origin.x + size.width, minX), 1)
        let maxY = min(max(origin.y + size.height, minY), 1)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
