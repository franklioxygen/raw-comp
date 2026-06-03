import Foundation

struct PixelReadout: Equatable, Sendable {
    var normalizedX: Double = 0
    var normalizedY: Double = 0
    var red: Int = 0
    var green: Int = 0
    var blue: Int = 0
    var luma: Int = 0

    static let empty = PixelReadout()

    var rgbText: String {
        "R:\(red) G:\(green) B:\(blue)"
    }

    var coordinatesText: String {
        String(format: "%.3f, %.3f", normalizedX, normalizedY)
    }
}
