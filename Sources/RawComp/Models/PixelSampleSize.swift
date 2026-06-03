import Foundation

enum PixelSampleSize: Int, CaseIterable, Codable, Sendable {
    case one = 1
    case three = 3
    case five = 5

    var titleKey: String {
        "histogram.sample.\(rawValue)x\(rawValue)"
    }
}
