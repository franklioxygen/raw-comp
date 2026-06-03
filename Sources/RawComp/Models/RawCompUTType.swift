import UniformTypeIdentifiers

extension UTType {
    /// JSON comparison session document (`.rawcomp`).
    static let rawCompSession = UTType(exportedAs: "com.rawcomp.session", conformingTo: .json)
}

enum RawCompSessionFile {
    static let preferredExtension = "rawcomp"
    static let defaultFilename = "Comparison.rawcomp"
}
