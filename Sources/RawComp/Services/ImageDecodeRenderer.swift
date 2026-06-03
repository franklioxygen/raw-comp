import CoreGraphics
import Foundation
import ImageIO
@preconcurrency import QuickLookThumbnailing

struct DecodedRaster: Sendable {
    let cgImage: CGImage
    let isPreview: Bool
}

/// Decodes files and caches raster data separately from adjustment/analysis renders.
actor ImageDecodeRenderer {
    static let shared = ImageDecodeRenderer()

    private struct CacheEntry {
        let modificationTimestamp: TimeInterval
        let cgImage: CGImage
        let isPreview: Bool
    }

    private let maxCacheEntries = 8
    private var entries: [String: CacheEntry] = [:]
    private var insertionOrder: [String] = []

    func decode(url: URL, isRAW: Bool) async throws -> DecodedRaster {
        let path = url.standardizedFileURL.path
        let modificationTimestamp = fileModificationTimestamp(for: url)

        if let entry = entries[path], entry.modificationTimestamp == modificationTimestamp {
            return DecodedRaster(cgImage: entry.cgImage, isPreview: entry.isPreview)
        }

        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        let raster: DecodedRaster
        if isRAW {
            if let preview = try await decodePreview(url: url, source: source) {
                raster = DecodedRaster(cgImage: preview, isPreview: true)
            } else if let full = decodeFull(source: source) {
                raster = DecodedRaster(cgImage: full, isPreview: false)
            } else {
                throw ImageLoadError.noDecoder(url)
            }
        } else if let full = decodeFull(source: source) {
            raster = DecodedRaster(cgImage: full, isPreview: false)
        } else if let preview = try await decodePreview(url: url, source: source) {
            raster = DecodedRaster(cgImage: preview, isPreview: true)
        } else {
            throw ImageLoadError.noDecoder(url)
        }

        insertEntry(path: path, entry: CacheEntry(
            modificationTimestamp: modificationTimestamp,
            cgImage: raster.cgImage,
            isPreview: raster.isPreview
        ))
        return raster
    }

    func baseCGImage(for loadedImage: LoadedImage, maxPreviewDimension: Int?) -> CGImage {
        let path = loadedImage.url.standardizedFileURL.path
        let modificationTimestamp = fileModificationTimestamp(for: loadedImage.url)
        let cached: CGImage

        if
            let entry = entries[path],
            entry.modificationTimestamp == modificationTimestamp,
            entry.isPreview == loadedImage.isPreview
        {
            cached = entry.cgImage
        } else {
            cached = loadedImage.cgImage
            insertEntry(path: path, entry: CacheEntry(
                modificationTimestamp: modificationTimestamp,
                cgImage: cached,
                isPreview: loadedImage.isPreview
            ))
        }

        guard let maxPreviewDimension else {
            return cached
        }

        return ImagePreviewScaler.downscale(cached, maxDimension: maxPreviewDimension) ?? cached
    }

    func invalidate(url: URL) {
        let path = url.standardizedFileURL.path
        entries.removeValue(forKey: path)
        insertionOrder.removeAll { $0 == path }
    }

    func clear() {
        entries.removeAll()
        insertionOrder.removeAll()
    }

    private func insertEntry(path: String, entry: CacheEntry) {
        if entries[path] == nil {
            insertionOrder.append(path)
        }
        entries[path] = entry
        while entries.count > maxCacheEntries, let oldest = insertionOrder.first {
            insertionOrder.removeFirst()
            entries.removeValue(forKey: oldest)
        }
    }

    private func decodeFull(source: CGImageSource?) -> CGImage? {
        guard let source else {
            return nil
        }

        let options: CFDictionary = [
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldAllowFloat: true
        ] as CFDictionary

        guard let image = CGImageSourceCreateImageAtIndex(source, 0, options) else {
            return nil
        }

        return WorkingColorSpace.sRGBCGImage(from: image)
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
                return WorkingColorSpace.sRGBCGImage(from: thumbnail)
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
                    continuation.resume(returning: WorkingColorSpace.sRGBCGImage(from: cgImage))
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

    private func fileModificationTimestamp(for url: URL) -> TimeInterval {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate?.timeIntervalSince1970 ?? 0
    }
}
