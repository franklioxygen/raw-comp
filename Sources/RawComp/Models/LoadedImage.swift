import AppKit
import CoreGraphics
import Foundation

struct ImageMetadataField: Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
}

struct ImageMetadata: Sendable {
    let fileName: String
    let fileType: String
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSizeBytes: Int64?
    let colorModel: String?
    let profileName: String?
    let usesRawPipeline: Bool
    let exifFields: [ImageMetadataField]

    var dimensionsText: String {
        "\(pixelWidth) x \(pixelHeight)"
    }

    var fileSizeText: String {
        guard let fileSizeBytes else {
            return "Unknown"
        }

        return ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    var basicExifSummary: String? {
        let lookup = Dictionary(uniqueKeysWithValues: exifFields.map { ($0.id, $0.value) })
        let values = [
            lookup["f_number"],
            lookup["iso"].map { "ISO \($0)" },
            lookup["exposure_time"],
            lookup["focal_length"],
            lookup["exposure_bias"]
        ].compactMap { $0 }

        guard !values.isEmpty else {
            return nil
        }

        return values.joined(separator: "   ")
    }
}

struct LoadedImage: @unchecked Sendable {
    let url: URL
    let cgImage: CGImage
    let metadata: ImageMetadata
    let isPreview: Bool

    var nsImage: NSImage {
        NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }
}
