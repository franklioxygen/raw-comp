import AppKit
import CoreGraphics
import Foundation

struct ImageMetadata: Sendable {
    let fileName: String
    let fileType: String
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSizeBytes: Int64?
    let colorModel: String?
    let profileName: String?
    let usesRawPipeline: Bool

    var dimensionsText: String {
        "\(pixelWidth) x \(pixelHeight)"
    }

    var fileSizeText: String {
        guard let fileSizeBytes else {
            return "Unknown"
        }

        return ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
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
