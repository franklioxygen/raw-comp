import AppKit
import Foundation

struct SectionClipboardPayload: Codable, Sendable {
    let section: AdjustmentSectionID
    let light: LightAdjustments?
    let toneCurve: ToneCurveAdjustments?
    let color: ColorAdjustments?
    let blackAndWhite: BlackAndWhiteAdjustments?
    let presence: PresenceAdjustments?
    let noise: NoiseAdjustments?
    let optics: OpticsAdjustments?
    let geometry: GeometryAdjustments?
    let compareMode: CompareModeSettings?

    init(section: AdjustmentSectionID, from adjustments: ComparisonAdjustments) {
        self.section = section
        light = section == .light ? adjustments.light : nil
        toneCurve = section == .toneCurve ? adjustments.toneCurve : nil
        color = section == .color ? adjustments.color : nil
        blackAndWhite = section == .blackAndWhite ? adjustments.blackAndWhite : nil
        presence = section == .presence ? adjustments.presence : nil
        noise = section == .noise ? adjustments.noise : nil
        optics = section == .optics ? adjustments.optics : nil
        geometry = section == .geometry ? adjustments.geometry : nil
        compareMode = section == .compareMode ? adjustments.compareMode : nil
    }

    func applying(to adjustments: ComparisonAdjustments) -> ComparisonAdjustments {
        var next = adjustments
        if let light {
            next.light = light
        }
        if let toneCurve {
            next.toneCurve = toneCurve
        }
        if let color {
            next.color = color
        }
        if let blackAndWhite {
            next.blackAndWhite = blackAndWhite
        }
        if let presence {
            next.presence = presence
        }
        if let noise {
            next.noise = noise
        }
        if let optics {
            next.optics = optics
        }
        if let geometry {
            next.geometry = geometry
        }
        if let compareMode {
            next.compareMode = compareMode
        }
        return next
    }
}

enum SectionClipboard {
    private static let pasteboardType = NSPasteboard.PasteboardType("com.rawcomp.adjustment-section")

    static func copy(_ payload: SectionClipboardPayload) {
        guard let data = try? JSONEncoder().encode(payload) else {
            return
        }

        let pasteboard = NSPasteboard.general
        // prepareForNewContents(with: []) writes only our custom type, leaving
        // system types (images, text, files) placed by other apps intact.
        pasteboard.prepareForNewContents(with: [])
        pasteboard.setData(data, forType: pasteboardType)
    }

    static func paste() -> SectionClipboardPayload? {
        guard
            let data = NSPasteboard.general.data(forType: pasteboardType),
            let payload = try? JSONDecoder().decode(SectionClipboardPayload.self, from: data)
        else {
            return nil
        }

        return payload
    }
}
