import Foundation

enum TimestampedFilename {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter
    }()

    static func make(baseName: String, pathExtension: String, date: Date = Date()) -> String {
        let stamp = formatter.string(from: date)
        if pathExtension.isEmpty {
            return "\(baseName) \(stamp)"
        }
        return "\(baseName) \(stamp).\(pathExtension)"
    }

    static func make(fromDefaultFilename defaultFilename: String, date: Date = Date()) -> String {
        let base = (defaultFilename as NSString).deletingPathExtension
        let pathExtension = (defaultFilename as NSString).pathExtension
        return make(baseName: base, pathExtension: pathExtension, date: date)
    }
}
