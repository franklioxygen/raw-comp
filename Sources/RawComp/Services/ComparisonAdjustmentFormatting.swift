import Foundation

enum ComparisonAdjustmentFormatting {
    static func parseNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let value = Double(trimmed) {
            return value
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        if let value = formatter.number(from: trimmed)?.doubleValue {
            return value
        }

        let separator = NSRegularExpression.escapedPattern(for: formatter.decimalSeparator ?? ".")
        let pattern = #"^[+-]?\d+(?:\#(separator)\d+)?"#
        guard
            let range = trimmed.range(of: pattern, options: .regularExpression)
        else {
            return nil
        }

        return formatter.number(from: String(trimmed[range]))?.doubleValue
    }
}
