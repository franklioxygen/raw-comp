import AppKit
import CoreGraphics
import Foundation

struct ImageMetadataField: Identifiable, Sendable {
    let id: String
    let labelKey: String
    let value: String
    let overlayValue: String

    init(id: String, labelKey: String, value: String, overlayValue: String? = nil) {
        self.id = id
        self.labelKey = labelKey
        self.value = value
        self.overlayValue = overlayValue ?? value
    }
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
            return L10n.string("common.unknown")
        }

        return ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    var pipelineText: String {
        usesRawPipeline
            ? L10n.string("inspector.pipeline.raw_preview")
            : L10n.string("inspector.pipeline.standard")
    }

    func topInfoLines(for selectedFieldIDs: Set<String>, paneTitle: String) -> [String] {
        TopInfoOverlayField.sortedFieldIDs(from: selectedFieldIDs).compactMap { fieldID in
            switch TopInfoOverlayField(rawValue: fieldID) {
            case .paneTitle:
                paneTitle
            case .fileName:
                fileName
            case .dimensions:
                dimensionsText
            case .fileType:
                fileType
            case .fileSize:
                fileSizeText
            case .colorModel:
                colorModel
            case .profileName:
                profileName
            case .pipeline:
                pipelineText
            case .none:
                nil
            }
        }
    }

    func exifSummary(for selectedFieldIDs: Set<String>) -> String? {
        let orderedFieldIDs = ExifOverlayField.sortedFieldIDs(from: selectedFieldIDs)
        guard !orderedFieldIDs.isEmpty else {
            return nil
        }

        let fieldLookup = Dictionary(uniqueKeysWithValues: exifFields.map { ($0.id, $0) })

        let values = orderedFieldIDs.compactMap { fieldID -> String? in
            guard let field = fieldLookup[fieldID] else {
                return nil
            }

            if fieldID == ExifOverlayField.iso.rawValue {
                return "ISO \(field.overlayValue)"
            }

            return field.overlayValue
        }

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
