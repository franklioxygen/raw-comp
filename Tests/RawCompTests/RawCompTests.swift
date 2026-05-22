import Testing
@testable import RawComp

@Test func layoutGridConfigurationMatchesPaneCounts() async throws {
    #expect(ComparisonLayout.two.columnCount == 2)
    #expect(ComparisonLayout.three.columnCount == 3)
    #expect(ComparisonLayout.four.columnCount == 2)
    #expect(ComparisonLayout.six.columnCount == 3)
}

@Test func supportedFormatsIncludeKeyRawAndCompressedTypes() async throws {
    #expect(ImageLoader.supportedExtensions.contains("cr3"))
    #expect(ImageLoader.supportedExtensions.contains("nef"))
    #expect(ImageLoader.supportedExtensions.contains("dng"))
    #expect(ImageLoader.supportedExtensions.contains("jpg"))
    #expect(ImageLoader.supportedExtensions.contains("png"))
}

@Test func comparisonAdjustmentsReportNeutralOnlyAtDefaults() async throws {
    var adjustments = ComparisonAdjustments()
    #expect(adjustments.isNeutral)

    adjustments.contrast = 1.2
    #expect(!adjustments.isNeutral)
}
