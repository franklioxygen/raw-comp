import AppKit
import Foundation
import ImageIO
import Observation
import UniformTypeIdentifiers

enum LinkMode: String, CaseIterable, Identifiable, Codable {
    case unlinked = "Free"
    case synced = "Synced"

    var id: String { rawValue }
}

private final class KeyMonitorHandle {
    private let monitor: Any

    init(_ monitor: Any) {
        self.monitor = monitor
    }

    deinit {
        NSEvent.removeMonitor(monitor)
    }
}

@Observable
@MainActor
final class WorkspaceStore {
    var layout: ComparisonLayout = .two {
        didSet {
            if !visiblePanes.contains(where: { $0.id == activePaneID }) {
                activePaneID = visiblePanes.first?.id
            }
            publishOnNextMainTurn { [weak self] in
                self?.sanitizeCompareModeForLayout()
                self?.updateBlinkTimer()
            }
            scheduleWorkspaceSnapshotSave()
        }
    }
    var linkMode: LinkMode = .synced {
        didSet {
            scheduleWorkspaceSnapshotSave()
        }
    }
    var highlightRect: CGRect?
    var showTopInfoBar = true
    var showExifOverlay = false
    var showInspector = true
    var adjustments = ComparisonAdjustments() {
        didSet {
            guard adjustments != oldValue else {
                return
            }

            let previous = oldValue
            let current = adjustments
            publishOnNextMainTurn { [weak self] in
                self?.processAdjustmentsChange(from: previous, to: current)
            }
        }
    }
    var activeHistogram: ImageHistogram?
    var activePixelReadout: PixelReadout?
    var referencePixelReadout: PixelReadout?
    var activePixelDeltaE: Double?
    var blinkShowsSecondary = false
    private(set) var emphasizesClippingIndicators = false
    var savedPresets: [SavedAdjustmentPreset] = AdjustmentPresetStore.loadPresets()
    private(set) var recentSessions: [URL] = RecentSessionsStore.load()
    var statusMessage = L10n.string("status.open_images")

    let panes: [ImagePaneState]

    private let imageLoader = ImageLoader.shared
    private let imageAdjustmentRenderer = ImageAdjustmentRenderer.shared
    private let imageAnalysisRenderer = ImageAnalysisRenderer.shared
    private let twoPaneAnalysisRenderer = TwoPaneAnalysisRenderer.shared
    private var activePaneID: UUID?
    private var adjustmentDispatchTask: Task<Void, Never>?
    private var blinkTimer: Timer?
    private var bypassKeyMonitorHandle: KeyMonitorHandle?
    private(set) var temporaryBypassPreview = false
    private var adjustedImageCache: [UUID: CGImage] = [:]
    private var adjustmentDragCount = 0
    private var usesPreviewQuality = false
    private var autosaveTask: Task<Void, Never>?
    private var snapshotTask: Task<Void, Never>?
    private var opticsByFilePath: [String: OpticsAdjustments] = PaneOpticsStore.load()
    private var syncingOpticsFromPaneChange = false
    private var pendingAdjustments: ComparisonAdjustments?
    private var isAdjustmentCommitScheduled = false

    init() {
        panes = (0..<6).map { ImagePaneState(slot: $0) }
        activePaneID = panes.first?.id
        var initial = ComparisonAdjustments()
        initial.inspector.expandedSections = InspectorPreferences.loadExpandedSections()
        initial.inspector.histogramDisplayMode = InspectorPreferences.loadHistogramDisplayMode()
        let autosaved = AdjustmentSessionPersistence.loadValues()
        let restoredAutosave = autosaved != nil
        if let autosaved {
            initial = autosaved.applying(to: initial)
            initial.inspector.expandedSections = InspectorPreferences.loadExpandedSections()
        }
        adjustments = initial
        installBypassKeyMonitor()

        if restoredAutosave {
            statusMessage = L10n.string("status.autosave_restored")
        }
    }


    var visiblePanes: [ImagePaneState] {
        Array(panes.prefix(layout.paneCount))
    }

    var activePane: ImagePaneState? {
        if let activePaneID {
            return panes.first(where: { $0.id == activePaneID })
        }

        return visiblePanes.first
    }

    func isSelected(_ pane: ImagePaneState) -> Bool {
        pane.id == activePane?.id
    }

    func selectPane(_ paneID: UUID) {
        guard activePaneID != paneID else {
            return
        }

        publishOnNextMainTurn { [weak self] in
            self?.applySelectPane(paneID)
        }
    }

    private func applySelectPane(_ paneID: UUID) {
        guard activePaneID != paneID else {
            return
        }

        persistOpticsForActivePane()
        activePaneID = paneID
        loadOpticsForActivePane()
        refreshActiveHistogram()
    }

    func openImages(replacing paneID: UUID? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = paneID == nil
        panel.message = L10n.string("open_panel.message")

        if panel.runModal() == .OK {
            importImages(urls: panel.urls, replacing: paneID)
        }
    }

    func importImages(urls: [URL], replacing paneID: UUID? = nil) {
        let normalizedURLs = urls.filter { !$0.pathExtension.isEmpty && !$0.hasDirectoryPath }
        guard !normalizedURLs.isEmpty else {
            statusMessage = L10n.string("status.no_loadable_files")
            return
        }

        if let paneID, let pane = panes.first(where: { $0.id == paneID }), let firstURL = normalizedURLs.first {
            load(url: firstURL, into: pane)
            return
        }

        if normalizedURLs.count == 1, let activePane, visiblePanes.contains(where: { $0.id == activePane.id }) {
            load(url: normalizedURLs[0], into: activePane)
            return
        }

        let targets = Array(visiblePanes.prefix(normalizedURLs.count))
        for (pane, url) in zip(targets, normalizedURLs) {
            load(url: url, into: pane)
        }

        if normalizedURLs.count > targets.count {
            statusMessage = L10n.string("status.loaded_first_n_files", targets.count, layout.paneCount)
        }
    }

    func loadDroppedItemProviders(_ providers: [NSItemProvider], into paneID: UUID) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] data, _ in
            guard
                let self,
                let data,
                let url = URL(dataRepresentation: data, relativeTo: nil)
            else {
                return
            }

            Task { @MainActor in
                self.importImages(urls: [url], replacing: paneID)
            }
        }

        return true
    }

    func updateViewport(from paneID: UUID, viewport: ViewportState) {
        publishOnNextMainTurn { [weak self] in
            self?.applyViewportUpdate(from: paneID, viewport: viewport)
        }
    }

    func zoomIn() {
        mutateActiveViewport { viewport in
            viewport.zoomMode = .manual
            viewport.zoomScale *= 1.25
        }
    }

    func zoomOut() {
        mutateActiveViewport { viewport in
            viewport.zoomMode = .manual
            viewport.zoomScale /= 1.25
        }
    }

    func fitToWindow() {
        mutateActiveViewport { viewport in
            viewport.zoomMode = .fit
        }
    }

    func actualPixels() {
        mutateActiveViewport { viewport in
            viewport.zoomMode = .actual
            viewport.zoomScale = 1.0
        }
    }

    func rotateLeft() {
        mutateActiveViewport { viewport in
            viewport.rotationQuarterTurns -= 1
        }
    }

    func rotateRight() {
        mutateActiveViewport { viewport in
            viewport.rotationQuarterTurns += 1
        }
    }

    func captureHighlightFromActivePane() {
        guard let activePane else {
            return
        }

        let rect = activePane.viewport.visibleRectNormalized.clampedUnit()
        guard rect.width > 0, rect.height > 0 else {
            statusMessage = L10n.string("status.no_visible_region")
            return
        }

        highlightRect = rect
        statusMessage = L10n.string("status.captured_region", activePane.title)
    }

    func clearHighlight() {
        highlightRect = nil
        statusMessage = L10n.string("status.cleared_region")
    }

    func updateAdjustmentValue(_ keyPath: WritableKeyPath<ComparisonAdjustments, Double>, to value: Double) {
        var next = adjustments
        guard next[keyPath: keyPath] != value else {
            return
        }
        next[keyPath: keyPath] = value
        commitAdjustments(next)
    }

    func updateAdjustmentFlag(_ keyPath: WritableKeyPath<ComparisonAdjustments, Bool>, to value: Bool) {
        var next = adjustments
        guard next[keyPath: keyPath] != value else {
            return
        }
        next[keyPath: keyPath] = value
        commitAdjustments(next)
    }

    func mutateAdjustments(_ transform: (inout ComparisonAdjustments) -> Void) {
        var next = adjustments
        transform(&next)
        commitAdjustments(next)
    }

    func resetAdjustments() {
        resetAllAdjustments()
    }

    func resetAllAdjustments() {
        var next = adjustments
        next.resetAllAdjustments()
        commitAdjustments(next)
    }

    func resetSection(_ section: AdjustmentSectionID, optionKey: Bool = false) {
        var next = adjustments
        next.resetSection(section)
        if optionKey {
            if section.isAdjustmentSection {
                next.inspector.enabledSections.insert(section)
            } else {
                next.inspector.enabledSections = InspectorPresentationState.default.enabledSections
            }
        }
        commitAdjustments(next)
    }

    func resetControl(_ keyPath: WritableKeyPath<ComparisonAdjustments, Double>) {
        var next = adjustments
        next[keyPath: keyPath] = ComparisonAdjustments.neutral[keyPath: keyPath]
        commitAdjustments(next)
    }

    func toggleSectionExpanded(_ section: AdjustmentSectionID, optionKey: Bool) {
        var next = adjustments
        if optionKey {
            next.inspector.expandedSections = [section]
        } else if next.inspector.expandedSections.contains(section) {
            next.inspector.expandedSections.remove(section)
        } else {
            next.inspector.expandedSections.insert(section)
        }
        commitAdjustments(next)
    }

    func toggleSectionEnabled(_ section: AdjustmentSectionID) {
        guard section.isAdjustmentSection else {
            return
        }

        var next = adjustments
        if next.inspector.enabledSections.contains(section) {
            next.inspector.enabledSections.remove(section)
        } else {
            next.inspector.enabledSections.insert(section)
        }
        commitAdjustments(next)
    }

    func setBypassAllAdjustments(_ bypass: Bool) {
        var next = adjustments
        next.inspector.bypassAllAdjustments = bypass
        commitAdjustments(next)
    }

    func setMonochromeCompare(_ enabled: Bool) {
        var next = adjustments
        next.blackAndWhite.monochromeCompare = enabled
        if enabled, next.compareMode.mode == .lumaOnly {
            next.compareMode.mode = .normal
        }
        commitAdjustments(next)
    }

    func setCompareMode(_ mode: CompareMode) {
        var next = adjustments
        guard !next.blackAndWhite.monochromeCompare || mode != .lumaOnly else {
            return
        }
        guard CompareMode.cases(for: layout).contains(mode) else {
            return
        }
        next.compareMode.mode = mode
        commitAdjustments(next)
        updateBlinkTimer()
        remindActualPixelsIfNeeded(for: mode)
    }

    func setNoiseEmphasisPreview(_ enabled: Bool) {
        var next = adjustments
        next.noise.noiseEmphasisPreview = enabled
        commitAdjustments(next)
        if enabled {
            remindActualPixelsIfNeeded(for: .noiseEmphasis)
        }
    }

    func displayCGImage(for pane: ImagePaneState) -> CGImage? {
        if isBlinkCompareActive {
            let sources = visiblePanes.prefix(2).compactMap { adjustedImageCache[$0.id] ?? $0.renderedCGImage ?? $0.loadedImage?.cgImage }
            guard sources.count == 2 else {
                return pane.renderedCGImage ?? pane.loadedImage?.cgImage
            }
            return blinkShowsSecondary ? sources[1] : sources[0]
        }

        return pane.renderedCGImage ?? pane.loadedImage?.cgImage
    }

    var isBlinkCompareActive: Bool {
        layout == .two && adjustments.compareMode.mode == .blink
    }

    var isWipeCompareActive: Bool {
        layout == .two && adjustments.compareMode.mode == .wipe
    }

    func setAdjustmentDragActive(_ active: Bool) {
        if active {
            adjustmentDragCount += 1
        } else {
            adjustmentDragCount = max(0, adjustmentDragCount - 1)
        }

        let nextPreview = adjustmentDragCount > 0
        guard usesPreviewQuality != nextPreview else {
            if active {
                scheduleAdjustmentRefresh()
            }
            return
        }

        usesPreviewQuality = nextPreview
        scheduleAdjustmentRefresh()
    }

    func setLightClippingPreviewActive(_ active: Bool) {
        guard emphasizesClippingIndicators != active else {
            return
        }
        publishOnNextMainTurn { [weak self] in
            self?.emphasizesClippingIndicators = active
        }
    }

    func setWipePosition(_ position: Double) {
        var next = adjustments
        next.compareMode.wipePosition = min(max(position, 0), 1)
        commitAdjustments(next)
    }

    func loadDefaultAdjustmentPreset() {
        var next = ComparisonAdjustments()
        next.inspector = adjustments.inspector
        commitAdjustments(next)
        statusMessage = L10n.string("status.preset_default_loaded")
    }

    func copySectionAdjustments(_ section: AdjustmentSectionID) {
        guard section.isAdjustmentSection else {
            return
        }

        SectionClipboard.copy(SectionClipboardPayload(section: section, from: adjustments))
        statusMessage = L10n.string("status.section_copied", L10n.string(section.titleKey))
    }

    func pasteSectionAdjustments() {
        guard let payload = SectionClipboard.paste() else {
            statusMessage = L10n.string("status.section_paste_failed")
            return
        }

        commitAdjustments(payload.applying(to: adjustments))
        statusMessage = L10n.string("status.section_pasted", L10n.string(payload.section.titleKey))
    }

    func saveSessionToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.rawCompSession, .json]
        panel.nameFieldStringValue = RawCompSessionFile.defaultFilename
        panel.message = L10n.string("session.save_panel_message")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        persistSession(to: url)
    }

    func openSessionFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.rawCompSession, .json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = L10n.string("session.open_panel_message")

        guard panel.runModal() == .OK, let url = panel.urls.first else {
            return
        }

        loadSession(from: url)
    }

    func showsCropOverlay(for pane: ImagePaneState) -> Bool {
        adjustments.inspector.enabledSections.contains(.geometry)
            && adjustments.geometry.showCropOverlay
    }

    func allowsCropEditing(for pane: ImagePaneState) -> Bool {
        showsCropOverlay(for: pane) && isSelected(pane)
    }

    var cropRectNormalized: CGRect {
        adjustments.geometry.cropRectNormalized.clampedUnit()
    }

    func setCropRectNormalized(_ rect: CGRect) {
        var next = adjustments
        next.geometry.cropRectNormalized = rect.clampedUnit()
        commitAdjustments(next)
    }

    func resetCropRect() {
        var next = adjustments
        next.geometry.cropRectNormalized = GeometryAdjustments.defaultCropRect
        commitAdjustments(next)
    }

    func reloadRecentSessions() {
        recentSessions = RecentSessionsStore.load()
    }

    func openRecentSession(at url: URL) {
        loadSession(from: url)
    }

    func removeRecentSession(at url: URL) {
        RecentSessionsStore.remove(url)
        reloadRecentSessions()
    }

    func clearRecentSessions() {
        RecentSessionsStore.clear()
        reloadRecentSessions()
    }

    var showsTwoPaneDeltaReadout: Bool {
        layout == .two && (adjustments.compareMode.mode == .deltaE || adjustments.compareMode.mode == .absoluteDifference)
    }

    func hasLensMetadata(for pane: ImagePaneState?) -> Bool {
        guard let pane, let metadata = pane.loadedImage?.metadata else {
            return false
        }

        return metadata.exifFields.contains { field in
            (field.id == "lens_model" || field.id == "focal_length") && !field.value.isEmpty
        }
    }

    func setTemporaryBypassPreview(_ enabled: Bool) {
        guard temporaryBypassPreview != enabled else {
            return
        }

        publishOnNextMainTurn { [weak self] in
            guard let self, self.temporaryBypassPreview != enabled else {
                return
            }
            self.temporaryBypassPreview = enabled
            self.applyAdjustmentsToLoadedPanes()
        }
    }

    func resetAllAdjustmentsIncludingInspector() {
        var next = ComparisonAdjustments()
        next.inspector.expandedSections = adjustments.inspector.expandedSections
        next.inspector.histogramDisplayMode = adjustments.inspector.histogramDisplayMode
        next.inspector.pixelSampleSize = adjustments.inspector.pixelSampleSize
        commitAdjustments(next)
    }

    func setToneCurvePreset(_ preset: ToneCurvePreset, channel: ToneCurveChannel) {
        var next = adjustments
        next.toneCurve.setPreset(preset, for: channel)
        commitAdjustments(next)
    }

    func setToneCurveCustomPoints(_ points: ToneCurvePoints, channel: ToneCurveChannel) {
        var next = adjustments
        var stored = points
        stored.clampMonotonic()
        if stored.isLinear {
            next.toneCurve.setCustomPoints(nil, for: channel)
        } else {
            next.toneCurve.setCustomPoints(stored, for: channel)
        }
        commitAdjustments(next)
    }

    func resetToneCurveMaster() {
        var next = adjustments
        next.toneCurve.resetMaster()
        commitAdjustments(next)
    }

    func resetToneCurveRGB() {
        var next = adjustments
        next.toneCurve.resetRGB()
        commitAdjustments(next)
    }

    func setPixelSampleSize(_ size: PixelSampleSize) {
        var next = adjustments
        next.inspector.pixelSampleSize = size
        commitAdjustments(next)
    }

    func setHistogramDisplayMode(_ mode: HistogramDisplayMode) {
        var next = adjustments
        next.inspector.histogramDisplayMode = mode
        commitAdjustments(next)
    }

    func exportComparisonToFile() {
        let loaded = visiblePanes.compactMap { pane -> (String, CGImage)? in
            guard
                let image = displayCGImage(for: pane) ?? pane.loadedImage?.cgImage
            else {
                return nil
            }

            return (pane.title, image)
        }

        guard !loaded.isEmpty else {
            statusMessage = L10n.string("status.export_no_images")
            return
        }

        guard
            let composite = ComparisonExportRenderer.renderGrid(
                panes: loaded,
                columns: layout.columnCount,
                includeLabels: LaunchWorkspacePreferences.exportIncludesLabels
            )
        else {
            statusMessage = L10n.string("status.export_failed")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .tiff]
        panel.nameFieldStringValue = L10n.string("export.default_filename")
        panel.message = L10n.string("export.save_panel_message")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let type = UTType(filenameExtension: url.pathExtension) ?? .png
        let success: Bool
        if type.conforms(to: .tiff) {
            success = writeTIFF(cgImage: composite, to: url)
        } else {
            success = writePNG(cgImage: composite, to: url)
        }

        statusMessage = success
            ? L10n.string("status.export_saved", url.lastPathComponent)
            : L10n.string("status.export_failed")
    }

    func toggleInspector() {
        showInspector.toggle()
    }

    func autoBalanceColorFromActivePane() {
        guard
            let activePane,
            let cgImage = adjustedImageCache[activePane.id] ?? activePane.loadedImage?.cgImage,
            let estimate = ColorBalanceEstimator.estimate(from: cgImage)
        else {
            statusMessage = L10n.string("status.auto_balance_failed")
            return
        }

        var next = adjustments
        next.color.temperature = estimate.temperature
        next.color.tint = estimate.tint
        commitAdjustments(next)
        statusMessage = L10n.string("status.auto_balance_applied")
    }

    func openMostRecentSession() {
        guard let url = recentSessions.first else {
            statusMessage = L10n.string("status.no_recent_session")
            return
        }

        loadSession(from: url)
    }

    func tryOpenLastSessionOnLaunch() {
        guard visiblePanes.allSatisfy({ $0.loadedImage == nil }) else {
            return
        }

        if LaunchWorkspacePreferences.openLastSessionOnLaunch,
           let url = RecentSessionsStore.load().first {
            loadSession(from: url)
            statusMessage = L10n.string("status.opened_last_session", url.lastPathComponent)
            return
        }

        restoreWorkspaceSnapshotIfNeeded()
    }

    func autoLightToneFromActivePane() {
        guard
            let activePane,
            let cgImage = adjustedImageCache[activePane.id] ?? activePane.loadedImage?.cgImage,
            let estimate = LightToneEstimator.estimate(from: cgImage)
        else {
            statusMessage = L10n.string("status.auto_light_failed")
            return
        }

        var next = adjustments
        next.light.exposureEV = estimate.exposureEV
        next.light.gamma = estimate.gamma
        commitAdjustments(next)
        statusMessage = L10n.string("status.auto_light_applied")
    }

    func copyActivePanePathToPasteboard() {
        guard let path = activePane?.loadedImage?.url.path else {
            statusMessage = L10n.string("status.copy_path_failed")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        statusMessage = L10n.string("status.copy_path_success")
    }

    var histogramReferenceLabel: String? {
        guard showsTwoPaneDeltaReadout, visiblePanes.count >= 2 else {
            return nil
        }

        let index = adjustments.compareMode.referencePane == .first ? 0 : 1
        return visiblePanes[index].title
    }

    func updatePixelReadout(normalizedPoint: CGPoint, from paneID: UUID) {
        guard activePane?.id == paneID else {
            return
        }

        guard
            let activePane,
            let cgImage = adjustedImageCache[activePane.id] ?? activePane.loadedImage?.cgImage
        else {
            publishPixelReadoutState(active: nil, reference: nil, deltaE: nil)
            return
        }

        let activeReadout = PixelSampler.sample(
            cgImage: cgImage,
            normalizedPoint: normalizedPoint,
            sampleSize: adjustments.inspector.pixelSampleSize
        )

        guard showsTwoPaneDeltaReadout, visiblePanes.count >= 2 else {
            publishPixelReadoutState(active: activeReadout, reference: nil, deltaE: nil)
            return
        }

        let referencePane = visiblePanes[adjustments.compareMode.referencePane == .first ? 0 : 1]
        guard let referenceImage = adjustedImageCache[referencePane.id] ?? referencePane.loadedImage?.cgImage else {
            publishPixelReadoutState(active: activeReadout, reference: nil, deltaE: nil)
            return
        }

        let referenceReadout = PixelSampler.sample(
            cgImage: referenceImage,
            normalizedPoint: normalizedPoint,
            sampleSize: adjustments.inspector.pixelSampleSize
        )

        let deltaE: Double?
        if referenceReadout != .empty {
            deltaE = PixelDelta.deltaE(readoutA: referenceReadout, readoutB: activeReadout)
        } else {
            deltaE = nil
        }

        publishPixelReadoutState(active: activeReadout, reference: referenceReadout, deltaE: deltaE)
    }

    func clearPixelReadout() {
        publishPixelReadoutState(active: nil, reference: nil, deltaE: nil)
    }

    func copyAdjustmentsToPasteboard() {
        AdjustmentPresetStore.copyToPasteboard(adjustments.adjustmentValues)
        statusMessage = L10n.string("status.adjustments_copied")
    }

    func pasteAdjustmentsFromPasteboard() {
        guard let values = AdjustmentPresetStore.pasteFromPasteboard() else {
            statusMessage = L10n.string("status.adjustments_paste_failed")
            return
        }

        commitAdjustments(values.applying(to: adjustments))
        statusMessage = L10n.string("status.adjustments_pasted")
    }

    func saveCurrentAdjustmentsAsPreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let preset = SavedAdjustmentPreset(name: trimmed, values: adjustments.adjustmentValues)
        savedPresets.append(preset)
        AdjustmentPresetStore.savePresets(savedPresets)
        statusMessage = L10n.string("status.preset_saved", trimmed)
    }

    func loadPreset(_ preset: SavedAdjustmentPreset) {
        commitAdjustments(preset.values.applying(to: adjustments))
        statusMessage = L10n.string("status.preset_loaded", preset.name)
    }

    func deletePreset(_ preset: SavedAdjustmentPreset) {
        savedPresets.removeAll { $0.id == preset.id }
        AdjustmentPresetStore.savePresets(savedPresets)
    }

    var activePaneIsBelowActualPixels: Bool {
        guard let viewport = activePane?.viewport else {
            return true
        }

        return viewport.zoomMode != .actual && viewport.zoomScale < 0.999
    }

    private func resampleActivePixelReadout() {
        guard
            let paneID = activePane?.id,
            let readout = activePixelReadout
        else {
            return
        }

        updatePixelReadout(
            normalizedPoint: CGPoint(x: readout.normalizedX, y: readout.normalizedY),
            from: paneID
        )
    }

    private func load(url: URL, into pane: ImagePaneState, restoringViewport: ViewportState? = nil) {
        pane.loadToken = UUID()
        let loadToken = pane.loadToken
        pane.adjustmentRevision += 1
        activePaneID = pane.id

        publishOnNextMainTurn { [weak self] in
            guard pane.loadToken == loadToken else {
                return
            }
            pane.loadState = .loading
            pane.loadedImage = nil
            pane.renderedCGImage = nil
            pane.viewport = restoringViewport ?? ViewportState()
            self?.adjustedImageCache.removeValue(forKey: pane.id)
            self?.statusMessage = L10n.string("status.loading_file", url.lastPathComponent)
        }

        Task {
            await ImageDecodeRenderer.shared.invalidate(url: url)
            do {
                let image = try await imageLoader.loadImage(from: url)
                await MainActor.run { [weak self] in
                    guard let self, pane.loadToken == loadToken else {
                        return
                    }

                    self.publishOnNextMainTurn { [weak self] in
                        guard let self, pane.loadToken == loadToken else {
                            return
                        }

                        pane.loadedImage = image
                        pane.renderedCGImage = image.cgImage
                        pane.loadState = .ready
                        pane.viewport = (restoringViewport ?? ViewportState()).clamped()
                        self.statusMessage = image.isPreview
                            ? L10n.string("status.loaded_preview", image.metadata.fileName)
                            : L10n.string("status.loaded_file", image.metadata.fileName)
                        if pane.id == self.activePane?.id {
                            self.loadOpticsForActivePane()
                        }
                        self.scheduleWorkspaceSnapshotSave()
                        self.applyAdjustmentsToLoadedPanes()
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, pane.loadToken == loadToken else {
                        return
                    }

                    self.publishOnNextMainTurn { [weak self] in
                        guard let self, pane.loadToken == loadToken else {
                            return
                        }
                        pane.loadState = .failed(error.localizedDescription)
                        pane.renderedCGImage = nil
                        self.statusMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func mutateActiveViewport(_ transform: (inout ViewportState) -> Void) {
        applyMutateActiveViewport(transform)
    }

    private func scheduleAdjustmentRefresh() {
        adjustmentDispatchTask?.cancel()
        let delayNanoseconds: UInt64 = usesPreviewQuality ? 75_000_000 : 100_000_000
        let preview = usesPreviewQuality
        adjustmentDispatchTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }

            self?.applyAdjustmentsToLoadedPanes(preview: preview)
        }
    }

    private func applyAdjustmentsToLoadedPanes(preview: Bool = false) {
        let currentAdjustments = adjustments
        let bypass = temporaryBypassPreview || currentAdjustments.inspector.bypassAllAdjustments
        let twoPaneMode = layout == .two && currentAdjustments.compareMode.mode.requiresTwoPanes
        let loadedPanes = visiblePanes.compactMap { pane -> (ImagePaneState, LoadedImage)? in
            guard let loadedImage = pane.loadedImage else {
                return nil
            }
            return (pane, loadedImage)
        }

        guard !loadedPanes.isEmpty else {
            return
        }

        for (pane, _) in loadedPanes {
            pane.adjustmentRevision += 1
        }

        let revisions = Dictionary(uniqueKeysWithValues: loadedPanes.map { ($0.0.id, $0.0.adjustmentRevision) })

        Task {
            let opticsSnapshot = opticsByFilePath
            var perPaneAdjusted: [UUID: CGImage] = [:]
            await withTaskGroup(of: (UUID, CGImage).self) { group in
                for (pane, loadedImage) in loadedPanes {
                    var paneAdjustments = currentAdjustments
                    paneAdjustments.optics = opticsSnapshot[loadedImage.url.path] ?? currentAdjustments.optics
                    let paneID = pane.id
                    group.addTask {
                        let adjusted = await self.imageAdjustmentRenderer.render(
                            loadedImage,
                            adjustments: paneAdjustments,
                            forceBypass: bypass,
                            maxPreviewDimension: preview ? 1024 : nil
                        ) ?? loadedImage.cgImage
                        return (paneID, adjusted)
                    }
                }
                for await (id, image) in group {
                    perPaneAdjusted[id] = image
                }
            }

            var displayImages = perPaneAdjusted
            if twoPaneMode, loadedPanes.count >= 2, currentAdjustments.compareMode.mode != .blink {
                let firstPane = loadedPanes[0].0
                let secondPane = loadedPanes[1].0
                if
                    let left = perPaneAdjusted[firstPane.id],
                    let right = perPaneAdjusted[secondPane.id]
                {
                    let composite = await twoPaneAnalysisRenderer.render(
                        leftImage: left,
                        rightImage: right,
                        mode: currentAdjustments.compareMode.mode,
                        settings: currentAdjustments.compareMode
                    )

                    if let composite {
                        displayImages[firstPane.id] = composite
                        displayImages[secondPane.id] = composite
                    }
                }
            }

            for (pane, loadedImage) in loadedPanes {
                guard let adjusted = perPaneAdjusted[pane.id] else {
                    continue
                }

                let usesComposite = twoPaneMode
                    && currentAdjustments.compareMode.mode != .blink
                    && loadedPanes.count >= 2
                let finalImage: CGImage
                if usesComposite, let display = displayImages[pane.id] {
                    finalImage = display
                } else {
                    finalImage = await imageAnalysisRenderer.render(
                        baseCGImage: adjusted,
                        adjustments: currentAdjustments,
                        forceClippingOverlay: emphasizesClippingIndicators
                    ) ?? adjusted
                }

                guard !Task.isCancelled else {
                    return
                }

                let revision = revisions[pane.id] ?? 0
                let isActivePane = pane.id == activePane?.id

                await MainActor.run { [weak self] in
                    guard let self else {
                        return
                    }

                    guard
                        pane.adjustmentRevision == revision,
                        pane.loadedImage?.url == loadedImage.url
                    else {
                        return
                    }

                    let histogram = isActivePane ? HistogramComputer.compute(from: finalImage) : nil
                    publishPaneRenderUpdate(
                        pane: pane,
                        renderedImage: finalImage,
                        adjustedCacheImage: adjusted,
                        histogram: histogram,
                        resampleReadout: isActivePane
                    )
                }
            }

            await MainActor.run {
                updateBlinkTimer()
            }
        }
    }

    private func sanitizeCompareModeForLayout() {
        guard !CompareMode.cases(for: layout).contains(adjustments.compareMode.mode) else {
            return
        }

        var next = adjustments
        next.compareMode.mode = .normal
        commitAdjustments(next)
    }

    private func updateBlinkTimer() {
        blinkTimer?.invalidate()
        blinkTimer = nil

        guard isBlinkCompareActive else {
            publishOnNextMainTurn { [weak self] in
                self?.blinkShowsSecondary = false
            }
            return
        }

        let interval = max(0.25, adjustments.compareMode.blinkIntervalSeconds)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.blinkShowsSecondary.toggle()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        blinkTimer = timer
    }

    private func scheduleAdjustmentAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
            } catch {
                return
            }

            guard let self else {
                return
            }

            AdjustmentSessionPersistence.saveValues(self.adjustments.adjustmentValues)
        }
    }

    private func persistSession(to url: URL) {
        let document = makeSessionDocument()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(document)
            try data.write(to: url, options: .atomic)
            RecentSessionsStore.record(url)
            reloadRecentSessions()
            statusMessage = L10n.string("status.session_saved", url.lastPathComponent)
        } catch {
            statusMessage = L10n.string("status.session_save_failed", error.localizedDescription)
        }
    }

    private func loadSession(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let raw = try JSONDecoder().decode(ComparisonSessionDocument.self, from: data)
            let document = ComparisonSessionDocument.migrate(raw)
            applySessionDocument(document)
            RecentSessionsStore.record(url)
            reloadRecentSessions()
            statusMessage = L10n.string("status.session_loaded", url.lastPathComponent)
        } catch {
            statusMessage = L10n.string("status.session_load_failed", error.localizedDescription)
        }
    }

    private func makeSessionDocument() -> ComparisonSessionDocument {
        persistOpticsForActivePane()
        return ComparisonSessionDocument(
            layout: layout,
            linkMode: linkMode,
            adjustments: adjustments.adjustmentValues,
            inspector: adjustments.inspector,
            opticsByFilePath: opticsByFilePath,
            panes: panes.compactMap { pane in
                guard let path = pane.loadedImage?.url.path else {
                    return nil
                }

                return PaneSessionState(
                    slot: pane.slot,
                    filePath: path,
                    viewport: pane.viewport
                )
            }
        )
    }

    private func applySessionDocument(_ document: ComparisonSessionDocument) {
        layout = document.layout
        linkMode = document.linkMode

        var next = ComparisonAdjustments()
        if let inspector = document.inspector {
            next.inspector = inspector
        } else {
            next.inspector.expandedSections = InspectorPreferences.loadExpandedSections()
        }
        next = document.adjustments.applying(to: next)
        adjustments = next
        opticsByFilePath = document.opticsByFilePath
        PaneOpticsStore.save(opticsByFilePath)
        loadOpticsForActivePane()

        for pane in panes {
            pane.loadedImage = nil
            pane.renderedCGImage = nil
            pane.loadState = .empty
            pane.viewport = ViewportState()
        }

        for paneState in document.panes {
            guard let pane = panes.first(where: { $0.slot == paneState.slot }) else {
                continue
            }

            let fileURL = URL(fileURLWithPath: paneState.filePath)
            if let viewport = paneState.viewport {
                pane.viewport = viewport
            }
            load(url: fileURL, into: pane, restoringViewport: paneState.viewport)
        }

        sanitizeCompareModeForLayout()
        updateBlinkTimer()
    }

    private func installBypassKeyMonitor() {
        let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else {
                return event
            }

            // keyCode 42 = backslash on ANSI/ISO keyboards, independent of locale.
            guard event.keyCode == 42 else {
                return event
            }

            Task { @MainActor in
                switch event.type {
                case .keyDown:
                    self.setTemporaryBypassPreview(true)
                case .keyUp:
                    self.setTemporaryBypassPreview(false)
                default:
                    break
                }
            }

            return event
        }
        if let monitor {
            bypassKeyMonitorHandle = KeyMonitorHandle(monitor)
        }
    }

    private func refreshActiveHistogram() {
        let cgImage = activePane?.renderedCGImage ?? activePane?.loadedImage?.cgImage
        let histogram = cgImage.map { HistogramComputer.compute(from: $0) }
        publishOnNextMainTurn { [weak self] in
            self?.activeHistogram = histogram
        }
    }

    private func publishOnNextMainTurn(_ update: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            update()
        }
    }

    private func commitAdjustments(_ next: ComparisonAdjustments) {
        guard adjustments != next else {
            return
        }
        pendingAdjustments = next
        guard !isAdjustmentCommitScheduled else {
            return
        }
        isAdjustmentCommitScheduled = true
        Task { @MainActor [weak self] in
            self?.flushPendingAdjustments()
        }
    }

    private func flushPendingAdjustments() {
        isAdjustmentCommitScheduled = false
        guard let pending = pendingAdjustments else {
            return
        }
        pendingAdjustments = nil
        guard adjustments != pending else {
            return
        }
        let clearOpticsSync = syncingOpticsFromPaneChange
        adjustments = pending
        if clearOpticsSync {
            syncingOpticsFromPaneChange = false
        }
        if let pendingAdjustments, pendingAdjustments != adjustments {
            commitAdjustments(pendingAdjustments)
        }
    }

    private func processAdjustmentsChange(from oldValue: ComparisonAdjustments, to newValue: ComparisonAdjustments) {
        if newValue.inspector.expandedSections != oldValue.inspector.expandedSections {
            InspectorPreferences.saveExpandedSections(newValue.inspector.expandedSections)
        }

        if newValue.inspector.histogramDisplayMode != oldValue.inspector.histogramDisplayMode {
            InspectorPreferences.saveHistogramDisplayMode(newValue.inspector.histogramDisplayMode)
        }

        if newValue.compareMode.mode != oldValue.compareMode.mode
            || newValue.compareMode.blinkIntervalSeconds != oldValue.compareMode.blinkIntervalSeconds {
            updateBlinkTimer()
        }

        if !syncingOpticsFromPaneChange, newValue.optics != oldValue.optics {
            persistOpticsForActivePane()
        }

        if newValue.inspector.pixelSampleSize != oldValue.inspector.pixelSampleSize {
            resampleActivePixelReadout()
        }

        scheduleAdjustmentRefresh()
        scheduleAdjustmentAutosave()
    }

    private func applyViewportUpdate(from paneID: UUID, viewport: ViewportState) {
        guard let sourcePane = panes.first(where: { $0.id == paneID }) else {
            return
        }

        let clamped = viewport.clamped()
        if sourcePane.viewport != clamped {
            sourcePane.viewport = clamped
        }

        guard linkMode == .synced else {
            return
        }

        for pane in visiblePanes where pane.id != paneID && pane.loadedImage != nil {
            pane.viewport = clamped
        }
    }

    private func applyMutateActiveViewport(_ transform: (inout ViewportState) -> Void) {
        guard let activePane else {
            return
        }

        var next = activePane.viewport
        transform(&next)
        next = next.clamped()
        activePane.viewport = next

        guard linkMode == .synced else {
            return
        }

        for pane in visiblePanes where pane.id != activePane.id && pane.loadedImage != nil {
            pane.viewport = next
        }
    }

    private func publishPixelReadoutState(
        active: PixelReadout?,
        reference: PixelReadout?,
        deltaE: Double?
    ) {
        publishOnNextMainTurn { [weak self] in
            self?.activePixelReadout = active
            self?.referencePixelReadout = reference
            self?.activePixelDeltaE = deltaE
        }
    }

    private func publishPaneRenderUpdate(
        pane: ImagePaneState,
        renderedImage: CGImage,
        adjustedCacheImage: CGImage,
        histogram: ImageHistogram?,
        resampleReadout: Bool
    ) {
        publishOnNextMainTurn { [weak self] in
            guard let self else {
                return
            }

            pane.renderedCGImage = renderedImage
            adjustedImageCache[pane.id] = adjustedCacheImage

            if resampleReadout {
                activeHistogram = histogram
                resampleActivePixelReadout()
            }
        }
    }

    private func persistOpticsForActivePane() {
        guard let path = activePane?.loadedImage?.url.path else {
            return
        }

        opticsByFilePath[path] = adjustments.optics
        PaneOpticsStore.save(opticsByFilePath)
    }

    private func loadOpticsForActivePane() {
        guard let path = activePane?.loadedImage?.url.path else {
            return
        }

        let stored = opticsByFilePath[path] ?? .neutral
        guard adjustments.optics != stored else {
            return
        }

        syncingOpticsFromPaneChange = true
        var next = adjustments
        next.optics = stored
        commitAdjustments(next)
    }

    private func writePNG(cgImage: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        return CGImageDestinationFinalize(destination)
    }

    private func writeTIFF(cgImage: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.tiff.identifier as CFString, 1, nil) else {
            return false
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        return CGImageDestinationFinalize(destination)
    }

    private func scheduleWorkspaceSnapshotSave() {
        snapshotTask?.cancel()
        snapshotTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }

            self?.persistWorkspaceSnapshot()
        }
    }

    private func persistWorkspaceSnapshot() {
        let paneStates = panes.compactMap { pane -> PaneSessionState? in
            guard let path = pane.loadedImage?.url.path else {
                return nil
            }

            return PaneSessionState(slot: pane.slot, filePath: path, viewport: pane.viewport)
        }

        guard !paneStates.isEmpty else {
            return
        }

        WorkspaceSnapshotPersistence.save(
            WorkspaceSnapshot(layout: layout, linkMode: linkMode, panes: paneStates)
        )
    }

    private func restoreWorkspaceSnapshotIfNeeded() {
        guard let snapshot = WorkspaceSnapshotPersistence.load() else {
            return
        }

        layout = snapshot.layout
        linkMode = snapshot.linkMode

        for paneState in snapshot.panes {
            guard let pane = panes.first(where: { $0.slot == paneState.slot }) else {
                continue
            }

            let fileURL = URL(fileURLWithPath: paneState.filePath)
            load(url: fileURL, into: pane, restoringViewport: paneState.viewport)
        }

        statusMessage = L10n.string("status.workspace_snapshot_restored")
    }

    private func remindActualPixelsIfNeeded(for mode: CompareMode) {
        guard activePaneIsBelowActualPixels else {
            return
        }

        switch mode {
        case .noiseEmphasis, .edgeMap:
            statusMessage = L10n.string("status.zoom_hint_noise_detail")
        default:
            break
        }
    }
}
