import Foundation

enum AdjustmentSessionPersistence {
    private static let valuesKey = "comparison.adjustments.autosave"

    static func loadValues() -> ComparisonAdjustmentValues? {
        guard
            let data = UserDefaults.standard.data(forKey: valuesKey),
            let values = try? JSONDecoder().decode(ComparisonAdjustmentValues.self, from: data)
        else {
            return nil
        }

        return values
    }

    static func saveValues(_ values: ComparisonAdjustmentValues) {
        do {
            let data = try JSONEncoder().encode(values)
            UserDefaults.standard.set(data, forKey: valuesKey)
        } catch {
            print("[AdjustmentSessionPersistence] Failed to encode adjustment values: \(error)")
        }
    }
}
