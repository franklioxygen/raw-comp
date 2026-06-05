import Foundation

enum ExifOverlayField: String, CaseIterable, Identifiable, Codable, Sendable {
    case dateOriginal = "date_original"
    case cameraMake = "camera_make"
    case cameraModel = "camera_model"
    case lensModel = "lens_model"
    case cameraMode = "camera_mode"
    case exposureTime = "exposure_time"
    case aperture = "f_number"
    case iso = "iso"
    case focalLength = "focal_length"
    case exposureBias = "exposure_bias"
    case meteringMode = "metering_mode"
    case whiteBalance = "white_balance"
    case flash = "flash"
    case software = "software"

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .dateOriginal:
            "exif.date_original"
        case .cameraMake:
            "exif.camera_make"
        case .cameraModel:
            "exif.camera_model"
        case .lensModel:
            "exif.lens"
        case .cameraMode:
            "exif.camera_mode"
        case .exposureTime:
            "exif.exposure"
        case .aperture:
            "exif.aperture"
        case .iso:
            "exif.iso"
        case .focalLength:
            "exif.focal_length"
        case .exposureBias:
            "exif.exposure_bias"
        case .meteringMode:
            "exif.metering"
        case .whiteBalance:
            "exif.white_balance"
        case .flash:
            "exif.flash"
        case .software:
            "exif.software"
        }
    }

    var label: String {
        L10n.string(labelKey)
    }

    static func sortedFieldIDs<S: Sequence>(from fieldIDs: S) -> [String] where S.Element == String {
        let selected = Set(fieldIDs)
        return allCases.map(\.rawValue).filter(selected.contains)
    }
}
