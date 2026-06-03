import AppKit
import Foundation

struct SavedAdjustmentPreset: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var values: ComparisonAdjustmentValues

    init(id: UUID = UUID(), name: String, values: ComparisonAdjustmentValues) {
        self.id = id
        self.name = name
        self.values = values
    }
}

struct ComparisonAdjustmentValues: Codable, Equatable, Sendable {
    var light = LightAdjustments()
    var toneCurve = ToneCurveAdjustments()
    var color = ColorAdjustments()
    var blackAndWhite = BlackAndWhiteAdjustments()
    var presence = PresenceAdjustments()
    var noise = NoiseAdjustments()
    var optics = OpticsAdjustments()
    var geometry = GeometryAdjustments()
    var compareMode = CompareModeSettings()
    var enabledSections: Set<AdjustmentSectionID> = InspectorPresentationState.default.enabledSections
    var bypassAllAdjustments: Bool = false

    init() {}

    init(from adjustments: ComparisonAdjustments) {
        light = adjustments.light
        toneCurve = adjustments.toneCurve
        color = adjustments.color
        blackAndWhite = adjustments.blackAndWhite
        presence = adjustments.presence
        noise = adjustments.noise
        optics = adjustments.optics
        geometry = adjustments.geometry
        compareMode = adjustments.compareMode
        enabledSections = adjustments.inspector.enabledSections
        bypassAllAdjustments = adjustments.inspector.bypassAllAdjustments
    }

    func applying(to adjustments: ComparisonAdjustments) -> ComparisonAdjustments {
        var next = adjustments
        next.light = light
        next.toneCurve = toneCurve
        next.color = color
        next.blackAndWhite = blackAndWhite
        next.presence = presence
        next.noise = noise
        next.optics = optics
        next.geometry = geometry
        next.compareMode = compareMode
        next.inspector.enabledSections = enabledSections
        next.inspector.bypassAllAdjustments = bypassAllAdjustments
        return next
    }

    private enum CodingKeys: String, CodingKey {
        case light
        case toneCurve
        case color
        case blackAndWhite
        case presence
        case noise
        case optics
        case geometry
        case compareMode
        case enabledSections
        case bypassAllAdjustments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        light = try container.decodeIfPresent(LightAdjustments.self, forKey: .light) ?? .neutral
        toneCurve = try container.decodeIfPresent(ToneCurveAdjustments.self, forKey: .toneCurve) ?? .neutral
        color = try container.decodeIfPresent(ColorAdjustments.self, forKey: .color) ?? .neutral
        blackAndWhite = try container.decodeIfPresent(BlackAndWhiteAdjustments.self, forKey: .blackAndWhite) ?? .neutral
        presence = try container.decodeIfPresent(PresenceAdjustments.self, forKey: .presence) ?? .neutral
        noise = try container.decodeIfPresent(NoiseAdjustments.self, forKey: .noise) ?? .neutral
        optics = try container.decodeIfPresent(OpticsAdjustments.self, forKey: .optics) ?? .neutral
        geometry = try container.decodeIfPresent(GeometryAdjustments.self, forKey: .geometry) ?? .neutral
        compareMode = try container.decodeIfPresent(CompareModeSettings.self, forKey: .compareMode) ?? .neutral
        enabledSections = try container.decodeIfPresent(Set<AdjustmentSectionID>.self, forKey: .enabledSections)
            ?? InspectorPresentationState.default.enabledSections
        bypassAllAdjustments = try container.decodeIfPresent(Bool.self, forKey: .bypassAllAdjustments) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(light, forKey: .light)
        try container.encode(toneCurve, forKey: .toneCurve)
        try container.encode(color, forKey: .color)
        try container.encode(blackAndWhite, forKey: .blackAndWhite)
        try container.encode(presence, forKey: .presence)
        try container.encode(noise, forKey: .noise)
        try container.encode(optics, forKey: .optics)
        try container.encode(geometry, forKey: .geometry)
        try container.encode(compareMode, forKey: .compareMode)
        try container.encode(enabledSections, forKey: .enabledSections)
        try container.encode(bypassAllAdjustments, forKey: .bypassAllAdjustments)
    }
}

enum AdjustmentPresetStore {
    private static let storageKey = "comparison.adjustment.presets"
    private static let pasteboardType = NSPasteboard.PasteboardType("com.rawcomp.adjustments")

    static func loadPresets() -> [SavedAdjustmentPreset] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let presets = try? JSONDecoder().decode([SavedAdjustmentPreset].self, from: data)
        else {
            return []
        }

        return presets
    }

    static func savePresets(_ presets: [SavedAdjustmentPreset]) {
        do {
            let data = try JSONEncoder().encode(presets)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[AdjustmentPresetStore] Failed to encode presets: \(error)")
        }
    }

    static func copyToPasteboard(_ values: ComparisonAdjustmentValues) {
        guard let data = try? JSONEncoder().encode(values) else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: pasteboardType)
    }

    static func pasteFromPasteboard() -> ComparisonAdjustmentValues? {
        guard
            let data = NSPasteboard.general.data(forType: pasteboardType),
            let values = try? JSONDecoder().decode(ComparisonAdjustmentValues.self, from: data)
        else {
            return nil
        }

        return values
    }
}
