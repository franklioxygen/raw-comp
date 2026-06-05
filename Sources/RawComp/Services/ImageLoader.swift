import AppKit
import Foundation
import ImageIO

enum ExifMetadataFormatter {
    enum OutputStyle {
        case localized
        case english
    }

    static func formatValue(_ value: Any?, id: String? = nil, style: OutputStyle = .localized) -> String? {
        switch value {
        case let value as String:
            formatString(value, id: id)
        case let value as NSNumber:
            formatNumber(value, id: id, style: style)
        case let values as [Any]:
            values.compactMap { formatValue($0, id: id, style: style) }.joined(separator: ", ")
        default:
            nil
        }
    }

    private static func formatString(_ value: String, id: String?) -> String {
        switch id {
        case "date_original":
            formatDateOriginal(value)
        default:
            value
        }
    }

    private static func formatNumber(_ number: NSNumber, id: String?, style: OutputStyle) -> String {
        let value = number.doubleValue
        switch id {
        case "camera_mode":
            return formatExposureProgram(number.intValue)
        case "exposure_time":
            return formatExposureTime(value, style: style)
        case "f_number":
            return formatAperture(value, style: style)
        case "focal_length":
            return formatFocalLength(value, style: style)
        case "exposure_bias":
            return formatExposureBias(value, style: style)
        case "metering_mode":
            return "Metering:\(formatMeteringMode(number.intValue))"
        case "white_balance":
            return "WB:\(formatWhiteBalance(number.intValue))"
        case "flash":
            return "Flash:\(formatFlash(number.intValue))"
        case "gps_latitude", "gps_longitude":
            return formatDegrees(value, style: style)
        default:
            break
        }

        if value.rounded() == value {
            return String(Int64(value))
        }

        return formatDecimal(value, maxFractionDigits: 3)
    }

    private static func formatDateOriginal(_ value: String) -> String {
        let parts = value.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard let rawDate = parts.first else {
            return value
        }

        let dateParts = rawDate.split(separator: ":")
        guard dateParts.count == 3 else {
            return value
        }

        let formattedDate = dateParts.joined(separator: "/")
        guard parts.count == 2 else {
            return formattedDate
        }

        return formattedDate + " " + parts[1]
    }

    private static func formatExposureTime(_ seconds: Double, style: OutputStyle) -> String {
        guard seconds > 0 else {
            return style == .english ? "0 s" : L10n.string("format.zero_seconds")
        }

        if seconds < 1 {
            let denominator = Int((1 / seconds).rounded())
            return style == .english ? "1/\(denominator) s" : L10n.string("format.fraction_seconds", denominator)
        }

        let formatted = formatDecimal(seconds, maxFractionDigits: 1)
        return style == .english ? "\(formatted) s" : L10n.string("format.seconds", formatted)
    }

    private static func formatAperture(_ value: Double, style: OutputStyle) -> String {
        let formatted = formatDecimal(value, maxFractionDigits: 1)
        return style == .english ? "f/\(formatted)" : L10n.string("format.aperture", formatted)
    }

    private static func formatFocalLength(_ value: Double, style: OutputStyle) -> String {
        let formatted = formatDecimal(value, maxFractionDigits: 1)
        return style == .english ? "\(formatted) mm" : L10n.string("format.focal_length", formatted)
    }

    private static func formatExposureBias(_ value: Double, style: OutputStyle) -> String {
        let formatted = formatSignedDecimal(value, maxFractionDigits: 2)
        return style == .english ? "\(formatted) EV" : L10n.string("format.bias_ev", formatted)
    }

    private static func formatDegrees(_ value: Double, style: OutputStyle) -> String {
        let formatted = formatDecimal(value, maxFractionDigits: 6)
        return style == .english ? "\(formatted) deg" : L10n.string("format.deg", formatted)
    }

    private static func formatDecimal(_ value: Double, maxFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(maxFractionDigits)f", value)
    }

    private static func formatSignedDecimal(_ value: Double, maxFractionDigits: Int) -> String {
        let formatted = formatDecimal(abs(value), maxFractionDigits: maxFractionDigits)
        if value > 0 {
            return "+\(formatted)"
        }
        if value < 0 {
            return "-\(formatted)"
        }
        return formatted
    }

    private static func formatExposureProgram(_ value: Int) -> String {
        switch value {
        case 1:
            return "Manual"
        case 2:
            return "Program"
        case 3:
            return "Aperture Priority"
        case 4:
            return "Shutter Priority"
        case 5:
            return "Creative Program"
        case 6:
            return "Action Program"
        case 7:
            return "Portrait"
        case 8:
            return "Landscape"
        default:
            return String(value)
        }
    }

    private static func formatMeteringMode(_ value: Int) -> String {
        switch value {
        case 1:
            return "Average"
        case 2:
            return "Center Weighted"
        case 3:
            return "Spot"
        case 4:
            return "Multi-Spot"
        case 5:
            return "Pattern"
        case 6:
            return "Partial"
        case 255:
            return "Other"
        default:
            return String(value)
        }
    }

    private static func formatWhiteBalance(_ value: Int) -> String {
        switch value {
        case 0:
            return "Auto"
        case 1:
            return "Manual"
        default:
            return String(value)
        }
    }

    private static func formatFlash(_ value: Int) -> String {
        (value & 0x1) == 0x1 ? "On" : "Off"
    }
}

enum ImageLoadError: LocalizedError {
    case unreadable(URL)
    case noDecoder(URL)
    case quickLookFailed(URL)

    var errorDescription: String? {
        switch self {
        case let .unreadable(url):
            L10n.string("error.unreadable_file", url.lastPathComponent)
        case let .noDecoder(url):
            L10n.string("error.no_decoder", url.lastPathComponent)
        case let .quickLookFailed(url):
            L10n.string("error.quicklook_failed", url.lastPathComponent)
        }
    }
}

actor ImageLoader {
    static let shared = ImageLoader()

    static let rawExtensions: Set<String> = [
        "3fr", "arw", "bay", "cap", "cr2", "cr3", "crw", "dcr", "dng", "erf",
        "fff", "iiq", "k25", "kdc", "mef", "mos", "nef", "nrw", "orf", "ori",
        "pef", "ptx", "raf", "rw1", "rw2", "sr2", "srf", "srw", "x3f"
    ]

    static let standardExtensions: Set<String> = [
        "gif", "heic", "heif", "jpeg", "jpg", "png", "tif", "tiff", "webp"
    ]

    static let supportedExtensions: Set<String> = rawExtensions.union(standardExtensions)

    func loadImage(from url: URL) async throws -> LoadedImage {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImageLoadError.unreadable(url)
        }

        let ext = url.pathExtension.lowercased()
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        let metadata = makeMetadata(url: url, source: source, rawHint: Self.rawExtensions.contains(ext))
        let isRAW = Self.rawExtensions.contains(ext)
        let raster = try await ImageDecodeRenderer.shared.decode(url: url, isRAW: isRAW)

        return LoadedImage(
            url: url,
            cgImage: raster.cgImage,
            metadata: metadata,
            isPreview: raster.isPreview
        )
    }

    private func makeMetadata(url: URL, source: CGImageSource?, rawHint: Bool) -> ImageMetadata {
        let properties = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] } ?? [:]
        let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        let colorModel = properties[kCGImagePropertyColorModel] as? String
        let profileName = properties[kCGImagePropertyProfileName] as? String
        let fileType = source
            .flatMap(CGImageSourceGetType)
            .map { $0 as String }
            ?? url.pathExtension.uppercased()
        let fileSizeBytes = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init)

        return ImageMetadata(
            fileName: url.lastPathComponent,
            fileType: fileType,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            fileSizeBytes: fileSizeBytes ?? nil,
            colorModel: colorModel,
            profileName: profileName,
            usesRawPipeline: rawHint,
            exifFields: makeExifFields(from: properties)
        )
    }

    private func makeExifFields(from properties: [CFString: Any]) -> [ImageMetadataField] {
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]

        let candidates: [(String, String, Any?)] = [
            ("camera_make", "exif.camera_make", tiff[kCGImagePropertyTIFFMake]),
            ("camera_model", "exif.camera_model", tiff[kCGImagePropertyTIFFModel]),
            ("lens_model", "exif.lens", exif[kCGImagePropertyExifLensModel]),
            ("date_original", "exif.date_original", exif[kCGImagePropertyExifDateTimeOriginal] ?? tiff[kCGImagePropertyTIFFDateTime]),
            ("camera_mode", "exif.camera_mode", exif[kCGImagePropertyExifExposureProgram]),
            ("exposure_time", "exif.exposure", exif[kCGImagePropertyExifExposureTime]),
            ("f_number", "exif.aperture", exif[kCGImagePropertyExifFNumber]),
            ("iso", "exif.iso", exif[kCGImagePropertyExifISOSpeedRatings]),
            ("focal_length", "exif.focal_length", exif[kCGImagePropertyExifFocalLength]),
            ("exposure_bias", "exif.exposure_bias", exif[kCGImagePropertyExifExposureBiasValue]),
            ("metering_mode", "exif.metering", exif[kCGImagePropertyExifMeteringMode]),
            ("white_balance", "exif.white_balance", exif[kCGImagePropertyExifWhiteBalance]),
            ("flash", "exif.flash", exif[kCGImagePropertyExifFlash]),
            ("software", "exif.software", tiff[kCGImagePropertyTIFFSoftware]),
            ("artist", "exif.artist", tiff[kCGImagePropertyTIFFArtist]),
            ("gps_latitude", "exif.gps_latitude", gps[kCGImagePropertyGPSLatitude]),
            ("gps_longitude", "exif.gps_longitude", gps[kCGImagePropertyGPSLongitude])
        ]

        return candidates.compactMap { id, labelKey, value in
            guard
                let text = formatMetadataValue(value, id: id, style: .localized),
                !text.isEmpty
            else {
                return nil
            }

            let overlayText = formatMetadataValue(value, id: id, style: .english) ?? text
            return ImageMetadataField(id: id, labelKey: labelKey, value: text, overlayValue: overlayText)
        }
    }

    private func formatMetadataValue(
        _ value: Any?,
        id: String? = nil,
        style: ExifMetadataFormatter.OutputStyle = .localized
    ) -> String? {
        ExifMetadataFormatter.formatValue(value, id: id, style: style)
    }
}
