import AppKit
import Foundation
import ImageIO
@preconcurrency import QuickLookThumbnailing

enum ImageLoadError: LocalizedError {
    case unreadable(URL)
    case noDecoder(URL)
    case quickLookFailed(URL)

    var errorDescription: String? {
        switch self {
        case let .unreadable(url):
            "Could not read \(url.lastPathComponent)."
        case let .noDecoder(url):
            "No available decoder could open \(url.lastPathComponent)."
        case let .quickLookFailed(url):
            "Quick Look could not generate a preview for \(url.lastPathComponent)."
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

        if Self.rawExtensions.contains(ext) {
            if let preview = try await decodePreview(url: url, source: source) {
                return LoadedImage(url: url, cgImage: preview, metadata: metadata, isPreview: true)
            }

            if let full = decodeFull(url: url, source: source) {
                return LoadedImage(url: url, cgImage: full, metadata: metadata, isPreview: false)
            }
        } else {
            if let full = decodeFull(url: url, source: source) {
                return LoadedImage(url: url, cgImage: full, metadata: metadata, isPreview: false)
            }

            if let preview = try await decodePreview(url: url, source: source) {
                return LoadedImage(url: url, cgImage: preview, metadata: metadata, isPreview: true)
            }
        }

        throw ImageLoadError.noDecoder(url)
    }

    private func decodeFull(url: URL, source: CGImageSource?) -> CGImage? {
        guard let source else {
            return nil
        }

        let options: CFDictionary = [
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldAllowFloat: true
        ] as CFDictionary

        return CGImageSourceCreateImageAtIndex(source, 0, options)
    }

    private func decodePreview(url: URL, source: CGImageSource?) async throws -> CGImage? {
        if let source {
            let options: CFDictionary = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 4096,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary

            if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options) {
                return thumbnail
            }
        }

        return try await quickLookPreview(url: url)
    }

    private func quickLookPreview(url: URL) async throws -> CGImage {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 4096, height: 4096),
            scale: 1,
            representationTypes: .thumbnail
        )

        return try await withCheckedThrowingContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
                if let cgImage = representation?.cgImage {
                    continuation.resume(returning: cgImage)
                    return
                }

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(throwing: ImageLoadError.quickLookFailed(url))
            }
        }
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
            ("camera_make", "Camera Make", tiff[kCGImagePropertyTIFFMake]),
            ("camera_model", "Camera Model", tiff[kCGImagePropertyTIFFModel]),
            ("lens_model", "Lens", exif[kCGImagePropertyExifLensModel]),
            ("date_original", "Date Original", exif[kCGImagePropertyExifDateTimeOriginal] ?? tiff[kCGImagePropertyTIFFDateTime]),
            ("exposure_time", "Exposure", exif[kCGImagePropertyExifExposureTime]),
            ("f_number", "Aperture", exif[kCGImagePropertyExifFNumber]),
            ("iso", "ISO", exif[kCGImagePropertyExifISOSpeedRatings]),
            ("focal_length", "Focal Length", exif[kCGImagePropertyExifFocalLength]),
            ("exposure_bias", "Exposure Bias", exif[kCGImagePropertyExifExposureBiasValue]),
            ("metering_mode", "Metering", exif[kCGImagePropertyExifMeteringMode]),
            ("white_balance", "White Balance", exif[kCGImagePropertyExifWhiteBalance]),
            ("flash", "Flash", exif[kCGImagePropertyExifFlash]),
            ("software", "Software", tiff[kCGImagePropertyTIFFSoftware]),
            ("artist", "Artist", tiff[kCGImagePropertyTIFFArtist]),
            ("gps_latitude", "GPS Latitude", gps[kCGImagePropertyGPSLatitude]),
            ("gps_longitude", "GPS Longitude", gps[kCGImagePropertyGPSLongitude])
        ]

        return candidates.compactMap { id, label, value in
            guard let text = formatMetadataValue(value, id: id), !text.isEmpty else {
                return nil
            }

            return ImageMetadataField(id: id, label: label, value: text)
        }
    }

    private func formatMetadataValue(_ value: Any?, id: String? = nil) -> String? {
        switch value {
        case let value as String:
            value
        case let value as NSNumber:
            formatNumber(value, id: id)
        case let values as [Any]:
            values.compactMap { formatMetadataValue($0, id: id) }.joined(separator: ", ")
        default:
            nil
        }
    }

    private func formatNumber(_ number: NSNumber, id: String?) -> String {
        let value = number.doubleValue
        switch id {
        case "exposure_time":
            return formatExposureTime(value)
        case "f_number":
            return "f/\(formatDecimal(value, maxFractionDigits: 1))"
        case "focal_length":
            return "\(formatDecimal(value, maxFractionDigits: 1)) mm"
        case "exposure_bias":
            return "\(formatSignedDecimal(value, maxFractionDigits: 2)) EV"
        case "gps_latitude", "gps_longitude":
            return "\(formatDecimal(value, maxFractionDigits: 6)) deg"
        default:
            break
        }

        if value.rounded() == value {
            return String(Int64(value))
        }

        return formatDecimal(value, maxFractionDigits: 3)
    }

    private func formatExposureTime(_ seconds: Double) -> String {
        guard seconds > 0 else {
            return "0 s"
        }

        if seconds < 1 {
            let denominator = Int((1 / seconds).rounded())
            return "1/\(denominator) s"
        }

        return "\(formatDecimal(seconds, maxFractionDigits: 1)) s"
    }

    private func formatDecimal(_ value: Double, maxFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(maxFractionDigits)f", value)
    }

    private func formatSignedDecimal(_ value: Double, maxFractionDigits: Int) -> String {
        let formatted = formatDecimal(abs(value), maxFractionDigits: maxFractionDigits)
        if value > 0 {
            return "+\(formatted)"
        }
        if value < 0 {
            return "-\(formatted)"
        }
        return formatted
    }
}
