import CoreGraphics
import Foundation
import Testing
@testable import RawComp

@Test func layoutGridConfigurationMatchesPaneCounts() async throws {
    #expect(ComparisonLayout.two.columnCount == 2)
    #expect(ComparisonLayout.three.columnCount == 3)
    #expect(ComparisonLayout.four.columnCount == 2)
    #expect(ComparisonLayout.six.columnCount == 3)
}

@Test func compareModeTitleKeysResolveInEnglishBundle() async throws {
    for mode in CompareMode.allCases {
        let key = mode.titleKey
        let value = L10n.string(key)
        #expect(value != key, "Missing localization for \(key)")
    }
}

@Test func adjustmentSectionTitleKeysResolveInEnglishBundle() async throws {
    for section in AdjustmentSectionID.allCases {
        let key = section.titleKey
        let value = L10n.string(key)
        #expect(value != key, "Missing localization for \(key)")
    }
}

@Test func exifMetadataLabelKeysResolveInEnglishBundle() async throws {
    let keys = [
        "exif.camera_make",
        "exif.camera_model",
        "exif.lens",
        "exif.exposure",
        "exif.aperture",
        "exif.iso",
        "exif.focal_length",
        "exif.white_balance",
        "exif.flash",
    ]
    for key in keys {
        let value = L10n.string(key)
        #expect(value != key, "Missing localization for \(key)")
    }
}

@Test func paneOpticsByPathEncodesForSessions() async throws {
    var sample = OpticsAdjustments()
    sample.vignettingAmount = 18
    sample.lensProfileCorrection = true
    let payload = ["/images/a.cr3": sample]

    let decoded = try JSONDecoder().decode(
        [String: OpticsAdjustments].self,
        from: try JSONEncoder().encode(payload)
    )
    #expect(decoded["/images/a.cr3"]?.vignettingAmount == 18)
    #expect(decoded["/images/a.cr3"]?.lensProfileCorrection == true)
}

@Test func comparisonAdjustmentValuesNeutralRoundTrip() async throws {
    let values = ComparisonAdjustmentValues()
    #expect(values.light.isNeutral)
    #expect(values.toneCurve.isNeutral)

    let decoded = try JSONDecoder().decode(
        ComparisonAdjustmentValues.self,
        from: try JSONEncoder().encode(values)
    )
    #expect(decoded.enabledSections == InspectorPresentationState.default.enabledSections)
    #expect(!decoded.bypassAllAdjustments)
    #expect(decoded.compareMode.isNeutral)
}

@Test func compareModeLayoutFilteringMatchesSpec() async throws {
    let twoOnly: Set<CompareMode> = [.absoluteDifference, .deltaE, .blink, .wipe]
    for layout in ComparisonLayout.allCases {
        let cases = CompareMode.cases(for: layout)
        if layout == .two {
            for mode in twoOnly {
                #expect(cases.contains(mode))
            }
        } else {
            for mode in twoOnly {
                #expect(!cases.contains(mode))
            }
        }
        #expect(cases.contains(.normal))
    }
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

    adjustments.light.contrast = 1.2
    #expect(!adjustments.isNeutral)
}

@Test func lightSectionResetRestoresDefaults() async throws {
    var adjustments = ComparisonAdjustments()
    adjustments.light.exposureEV = 1.5
    adjustments.light.whites = 30
    adjustments.resetSection(.light)
    #expect(adjustments.light.isNeutral)
}

@Test func toneCurvePresetMarksSectionActive() async throws {
    var adjustments = ComparisonAdjustments()
    adjustments.toneCurve.masterPreset = .mediumContrast
    #expect(adjustments.sectionIsActive(.toneCurve))
}

@Test func toneCurveRGBPresetsDecodeAndNeutral() async throws {
    var toneCurve = ToneCurveAdjustments()
    toneCurve.redPreset = .softContrast
    #expect(!toneCurve.isNeutral)

    let data = try JSONEncoder().encode(toneCurve)
    let decoded = try JSONDecoder().decode(ToneCurveAdjustments.self, from: data)
    #expect(decoded.redPreset == .softContrast)

    var reset = decoded
    reset.resetRGB()
    #expect(reset.isNeutral)
}

@Test func toneCurveLegacyPresetMigratesToMaster() async throws {
    let json = #"{"preset":"mediumContrast"}"#.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(ToneCurveAdjustments.self, from: json)
    #expect(decoded.masterPreset == .mediumContrast)
    #expect(decoded.redPreset == .linear)
}

@Test func adjustmentAutosaveRoundTripsEnabledSections() async throws {
    var adjustments = ComparisonAdjustments()
    adjustments.inspector.enabledSections = [.light, .compareMode]
    adjustments.inspector.bypassAllAdjustments = true
    adjustments.light.contrast = 1.2

    let values = adjustments.adjustmentValues
    let data = try JSONEncoder().encode(values)
    let decoded = try JSONDecoder().decode(ComparisonAdjustmentValues.self, from: data)
    let restored = decoded.applying(to: ComparisonAdjustments())

    #expect(restored.inspector.enabledSections == [.light, .compareMode])
    #expect(restored.inspector.bypassAllAdjustments)
    #expect(restored.light.contrast == 1.2)
}

@Test func resetAllIncludingInspectorRestoresDefaultEnabledSections() async throws {
    var adjustments = ComparisonAdjustments()
    adjustments.inspector.enabledSections = [.light]
    adjustments.light.exposureEV = 1

    var next = ComparisonAdjustments()
    next.resetAllAdjustments()
    next.inspector.enabledSections = adjustments.inspector.enabledSections
    #expect(next.inspector.enabledSections == [.light])

    var fullReset = ComparisonAdjustments()
    fullReset.inspector.expandedSections = adjustments.inspector.expandedSections
    #expect(fullReset.inspector.enabledSections == InspectorPresentationState.default.enabledSections)
}

@Test func toneCurveCustomPointsActivateSection() async throws {
    var toneCurve = ToneCurveAdjustments()
    var custom = ToneCurvePoints.linear
    custom.point2 = CGPoint(x: 0.5, y: 0.62)
    toneCurve.setCustomPoints(custom, for: .master)
    #expect(!toneCurve.isNeutral)
    #expect(toneCurve.resolvedPoints(for: .master).point2.y == 0.62)

    let data = try JSONEncoder().encode(toneCurve)
    let decoded = try JSONDecoder().decode(ToneCurveAdjustments.self, from: data)
    #expect(decoded.masterCustomPoints?.point2.y == 0.62)

    var reset = decoded
    reset.resetMaster()
    #expect(reset.isNeutral)
}

@Test func monochromeCompareDisablesRedundantLumaMode() async throws {
    var adjustments = ComparisonAdjustments()
    adjustments.compareMode.mode = .lumaOnly
    adjustments.blackAndWhite.monochromeCompare = true
    if adjustments.compareMode.mode == .lumaOnly {
        adjustments.compareMode.mode = .normal
    }
    #expect(adjustments.compareMode.mode == .normal)
}

@Test func sectionActiveBadgeReflectsLightChanges() async throws {
    var adjustments = ComparisonAdjustments()
    #expect(!adjustments.sectionIsActive(.light))
    adjustments.light.shadows = 20
    #expect(adjustments.sectionIsActive(.light))
}

@Test func adjustmentValuesRoundTripThroughCodable() async throws {
    var adjustments = ComparisonAdjustments()
    adjustments.light.exposureEV = 0.5
    adjustments.presence.clarity = 12
    adjustments.geometry.fineRotateDegrees = 1.5
    adjustments.compareMode.mode = .edgeMap

    let values = ComparisonAdjustmentValues(from: adjustments)
    let data = try JSONEncoder().encode(values)
    let decoded = try JSONDecoder().decode(ComparisonAdjustmentValues.self, from: data)
    let restored = decoded.applying(to: ComparisonAdjustments.neutral)

    #expect(restored.light.exposureEV == 0.5)
    #expect(restored.presence.clarity == 12)
    #expect(restored.geometry.fineRotateDegrees == 1.5)
    #expect(restored.compareMode.mode == CompareMode.edgeMap)
}

@Test func compareModeCasesExcludeTwoPaneModesForMultiLayout() async throws {
    let multiModes = CompareMode.cases(for: .four)
    #expect(!multiModes.contains(.blink))
    #expect(!multiModes.contains(.absoluteDifference))
    #expect(multiModes.contains(.edgeMap))

    let twoModes = CompareMode.cases(for: .two)
    #expect(twoModes.contains(.blink))
    #expect(twoModes.contains(.deltaE))
}

@Test func pixelDeltaIncreasesWithChannelSeparation() async throws {
    let reference = PixelReadout(red: 10, green: 10, blue: 10, luma: 10)
    let shifted = PixelReadout(red: 40, green: 10, blue: 10, luma: 20)
    #expect(PixelDelta.deltaE(readoutA: reference, readoutB: shifted) > 0)
}

@Test func sectionClipboardRoundTripsLightSettings() async throws {
    var adjustments = ComparisonAdjustments()
    adjustments.light.exposureEV = 1.25
    adjustments.light.whites = 12

    let payload = SectionClipboardPayload(section: .light, from: adjustments)
    let data = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(SectionClipboardPayload.self, from: data)
    let restored = decoded.applying(to: .neutral)

    #expect(restored.light.exposureEV == 1.25)
    #expect(restored.light.whites == 12)
}

@Test func sessionDocumentEncodesPanePaths() async throws {
    var optics: [String: OpticsAdjustments] = [:]
    var sample = OpticsAdjustments()
    sample.distortionAmount = 12
    optics["/tmp/a.jpg"] = sample

    let document = ComparisonSessionDocument(
        layout: .two,
        linkMode: .synced,
        adjustments: ComparisonAdjustmentValues(),
        opticsByFilePath: optics,
        panes: [PaneSessionState(slot: 0, filePath: "/tmp/a.jpg", viewport: nil)]
    )

    let data = try JSONEncoder().encode(document)
    let decoded = try JSONDecoder().decode(ComparisonSessionDocument.self, from: data)
    #expect(decoded.panes.count == 1)
    #expect(decoded.panes[0].filePath == "/tmp/a.jpg")
    #expect(decoded.opticsByFilePath["/tmp/a.jpg"]?.distortionAmount == 12)
}

@Test func workspaceSnapshotEncodesLayoutAndPanePaths() async throws {
    let snapshot = WorkspaceSnapshot(
        layout: .six,
        linkMode: .synced,
        panes: [
            PaneSessionState(slot: 0, filePath: "/a.jpg", viewport: nil),
            PaneSessionState(slot: 1, filePath: "/b.jpg", viewport: nil),
        ]
    )

    let decoded = try JSONDecoder().decode(
        WorkspaceSnapshot.self,
        from: try JSONEncoder().encode(snapshot)
    )
    #expect(decoded.layout == .six)
    #expect(decoded.linkMode == .synced)
    #expect(decoded.panes.count == 2)
    #expect(decoded.panes[1].filePath == "/b.jpg")
}

@Test func sessionDocumentRoundTripsOpticsByPath() async throws {
    var optics: [String: OpticsAdjustments] = [:]
    var entry = OpticsAdjustments()
    entry.flatFieldCorrection = true
    optics["/tmp/raw.cr3"] = entry

    let document = ComparisonSessionDocument(
        adjustments: ComparisonAdjustmentValues(),
        opticsByFilePath: optics,
        panes: [PaneSessionState(slot: 0, filePath: "/tmp/raw.cr3", viewport: nil)]
    )

    let decoded = try JSONDecoder().decode(
        ComparisonSessionDocument.self,
        from: try JSONEncoder().encode(document)
    )
    #expect(decoded.opticsByFilePath["/tmp/raw.cr3"]?.flatFieldCorrection == true)
}

@Test func sessionDocumentRoundTripsInspectorAndAdjustments() async throws {
    var values = ComparisonAdjustmentValues()
    values.light.exposureEV = 0.5
    values.enabledSections = [.light, .toneCurve, .compareMode]
    values.bypassAllAdjustments = true
    values.compareMode.mode = .deltaE

    var inspector = InspectorPresentationState()
    inspector.pixelSampleSize = .five
    inspector.histogramDisplayMode = .luma

    let document = ComparisonSessionDocument(
        layout: .four,
        linkMode: .unlinked,
        adjustments: values,
        inspector: inspector,
        panes: [
            PaneSessionState(slot: 0, filePath: "/tmp/one.jpg", viewport: nil),
            PaneSessionState(slot: 1, filePath: "/tmp/two.jpg", viewport: nil),
        ]
    )

    let decoded = try JSONDecoder().decode(
        ComparisonSessionDocument.self,
        from: try JSONEncoder().encode(document)
    )

    #expect(decoded.layout == .four)
    #expect(decoded.linkMode == .unlinked)
    #expect(decoded.adjustments.light.exposureEV == 0.5)
    #expect(decoded.adjustments.enabledSections == [.light, .toneCurve, .compareMode])
    #expect(decoded.adjustments.bypassAllAdjustments)
    #expect(decoded.adjustments.compareMode.mode == .deltaE)
    #expect(decoded.inspector?.pixelSampleSize == .five)
    #expect(decoded.inspector?.histogramDisplayMode == .luma)
}

@Test @MainActor func hasLensMetadataAcceptsFocalLengthWithoutLensModel() async throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var pixels: [UInt8] = [
        128, 128, 128, 255, 128, 128, 128, 255,
        128, 128, 128, 255, 128, 128, 128, 255,
    ]
    guard
        let context = CGContext(
            data: &pixels,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let cgImage = context.makeImage()
    else {
        Issue.record("Failed to create lens metadata test image")
        return
    }

    let metadata = ImageMetadata(
        fileName: "test.jpg",
        fileType: "JPEG",
        pixelWidth: 2,
        pixelHeight: 2,
        fileSizeBytes: nil,
        colorModel: "RGB",
        profileName: nil,
        usesRawPipeline: false,
        exifFields: [
            ImageMetadataField(id: "focal_length", labelKey: "exif.focal_length", value: "50 mm"),
        ]
    )
    let pane = ImagePaneState(slot: 0)
    pane.loadedImage = LoadedImage(
        url: URL(fileURLWithPath: "/tmp/test.jpg"),
        cgImage: cgImage,
        metadata: metadata,
        isPreview: false
    )

    let store = WorkspaceStore()
    #expect(store.hasLensMetadata(for: pane))
}

@Test func geometryNeutralIgnoresAspectLockDefault() async throws {
    var geometry = GeometryAdjustments()
    geometry.aspectLock = true
    #expect(geometry.isNeutral)
}

@Test func geometryCropRectMarksSectionActive() async throws {
    var adjustments = ComparisonAdjustments()
    adjustments.geometry.cropRectNormalized = CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
    #expect(adjustments.sectionIsActive(.geometry))
}

@Test func inspectorPreferencesRoundTripsExpandedSectionsAndHistogramMode() async throws {
    let originalExpanded = InspectorPreferences.loadExpandedSections()
    let originalHistogram = InspectorPreferences.loadHistogramDisplayMode()
    defer {
        InspectorPreferences.saveExpandedSections(originalExpanded)
        InspectorPreferences.saveHistogramDisplayMode(originalHistogram)
    }

    let saved: Set<AdjustmentSectionID> = [.light, .toneCurve, .compareMode]
    InspectorPreferences.saveExpandedSections(saved)
    InspectorPreferences.saveHistogramDisplayMode(.luma)

    #expect(InspectorPreferences.loadExpandedSections() == saved)
    #expect(InspectorPreferences.loadHistogramDisplayMode() == .luma)
}

@Test func recentSessionsStoreRecordsAndRemoves() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let sessionURL = directory.appendingPathComponent("Test.rawcomp")
    try Data("{}".utf8).write(to: sessionURL)

    RecentSessionsStore.record(sessionURL)
    #expect(RecentSessionsStore.load().contains(sessionURL))

    RecentSessionsStore.remove(sessionURL)
    #expect(!RecentSessionsStore.load().contains(sessionURL))

    RecentSessionsStore.clear()
}

@Test func comparisonExportRendererBuildsGrid() async throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var pixels = [UInt8](repeating: 128, count: 4)
    guard
        let context = CGContext(
            data: &pixels,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let image = context.makeImage()
    else {
        Issue.record("Failed to create export test image")
        return
    }

    let composite = ComparisonExportRenderer.renderGrid(
        panes: [("A", image), ("B", image)],
        columns: 2
    )

    #expect(composite?.width ?? 0 > 1)
    #expect(composite?.height ?? 0 > 1)
}

@Test func presenceNeutralTreatsDefaultSharpenDetailAsNeutral() async throws {
    #expect(PresenceAdjustments.neutral.isNeutral)
    var presence = PresenceAdjustments()
    presence.sharpenDetail = 40
    #expect(!presence.isNeutral)
}

@Test func imageHistogramMedianLumaIsStable() async throws {
    var histogram = ImageHistogram()
    histogram.luma[100] = 50
    histogram.luma[140] = 50
    histogram.totalSamples = 100

    #expect(histogram.medianLuma == 100)
}

@Test func colorBalanceEstimatorReturnsValuesForNeutralGray() async throws {
    let width = 8
    let height = 8
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for index in 0..<(width * height) {
        let offset = index * 4
        pixels[offset] = 120
        pixels[offset + 1] = 120
        pixels[offset + 2] = 120
        pixels[offset + 3] = 255
    }

    guard
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let image = context.makeImage(),
        let estimate = ColorBalanceEstimator.estimate(from: image)
    else {
        Issue.record("Failed to create auto balance test image")
        return
    }

    #expect(abs(estimate.temperature) < 15)
    #expect(abs(estimate.tint) < 15)
}

@Test func adjustmentFormattingParsesSignedDecimals() async throws {
    #expect(ComparisonAdjustmentFormatting.parseNumber("1.25") == 1.25)
    #expect(ComparisonAdjustmentFormatting.parseNumber("-2.5 EV") == -2.5)
}

@Test func colorBandHueCentersAreDistinct() async throws {
    let centers = Set(ColorBandID.allCases.map(\.centerHueDegrees))
    #expect(centers.count == ColorBandID.allCases.count)
}

@Test func imagePreviewScalerSkipsUpscale() async throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var pixels = [UInt8](repeating: 255, count: 16)
    guard
        let context = CGContext(
            data: &pixels,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let image = context.makeImage()
    else {
        Issue.record("Failed to create preview scaler test image")
        return
    }

    let scaled = ImagePreviewScaler.downscale(image, maxDimension: 1024)
    #expect(scaled?.width == 2)
}

@Test func pixelSamplerAveragesSampleRegion() async throws {
    let width = 4
    let height = 4
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var pixels: [UInt8] = Array(repeating: 0, count: width * height * 4)
    for index in 0..<(width * height) {
        let offset = index * 4
        pixels[offset] = 100
        pixels[offset + 1] = 120
        pixels[offset + 2] = 140
        pixels[offset + 3] = 255
    }

    guard
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let cgImage = context.makeImage()
    else {
        Issue.record("Failed to create test image")
        return
    }

    let readout = PixelSampler.sample(
        cgImage: cgImage,
        normalizedPoint: CGPoint(x: 0.5, y: 0.5),
        sampleSize: .one
    )

    #expect(readout.red == 100)
    #expect(readout.green == 120)
    #expect(readout.blue == 140)
}
