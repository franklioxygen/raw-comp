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
            usesRawPipeline: rawHint
        )
    }
}
