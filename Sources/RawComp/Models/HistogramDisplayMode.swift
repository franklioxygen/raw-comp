import Foundation

enum HistogramDisplayMode: String, CaseIterable, Codable, Sendable {
    case rgb
    case luma

    var titleKey: String {
        "histogram.display.\(rawValue)"
    }
}
