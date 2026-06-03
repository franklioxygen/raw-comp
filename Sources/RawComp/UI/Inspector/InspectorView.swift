import AppKit
import SwiftUI

struct InspectorView: View {
    var store: WorkspaceStore
    @State private var presetName = ""
    @State private var showsColorMixer = false
    @State private var toneCurveChannel: ToneCurveChannel = .master

    var body: some View {
        let pane = store.activePane
        let metadata = pane?.loadedImage?.metadata

        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                inspectorHeader
                presetControls

                ForEach(visibleSections, id: \.self) { section in
                    sectionView(section, pane: pane, metadata: metadata)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var visibleSections: [AdjustmentSectionID] {
        [
            .histogram,
            .light,
            .toneCurve,
            .color,
            .blackAndWhite,
            .presence,
            .noise,
            .optics,
            .geometry,
            .compareMode,
            .metadata
        ]
    }

    private var inspectorHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    L10n.text("adjustments.title")
                        .font(.title3.weight(.semibold))
                    Text(store.adjustments.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Toggle(isOn: bypassBinding) {
                    L10n.text("adjustments.bypass")
                        .font(.caption.weight(.medium))
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(L10n.string("adjustments.bypass_hold_hint"))

                Spacer()

                Button(L10n.string("common.reset")) {
                    if NSEvent.modifierFlags.contains(.option) {
                        store.resetAllAdjustmentsIncludingInspector()
                    } else {
                        store.resetAllAdjustments()
                    }
                }
                .disabled(store.adjustments.isNeutral && !store.adjustments.inspector.bypassAllAdjustments)
                .help(L10n.string("adjustments.reset_option_hint"))
            }
        }
        .padding(.bottom, 4)
    }

    private var presetControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button(L10n.string("presets.copy")) {
                    store.copyAdjustmentsToPasteboard()
                }
                Button(L10n.string("presets.paste")) {
                    store.pasteAdjustmentsFromPasteboard()
                }
                Button(L10n.string("presets.default")) {
                    store.loadDefaultAdjustmentPreset()
                }
            }
            .controlSize(.small)

            HStack(spacing: 6) {
                TextField(L10n.string("presets.name_placeholder"), text: $presetName)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)

                Button(L10n.string("presets.save")) {
                    store.saveCurrentAdjustmentsAsPreset(named: presetName)
                    presetName = ""
                }
                .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !store.savedPresets.isEmpty {
                Menu(L10n.string("presets.load_label")) {
                    ForEach(store.savedPresets) { preset in
                        Button(preset.name) {
                            store.loadPreset(preset)
                        }
                        Button(L10n.string("presets.delete", preset.name), role: .destructive) {
                            store.deletePreset(preset)
                        }
                    }
                }
                .font(.caption)
            }
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func sectionView(
        _ section: AdjustmentSectionID,
        pane: ImagePaneState?,
        metadata: ImageMetadata?
    ) -> some View {
        let presentation = store.adjustments.inspector
        let isExpanded = presentation.expandedSections.contains(section)
        let isEnabled = section == .histogram || section == .metadata
            || presentation.enabledSections.contains(section)
        let isActive = store.adjustments.sectionIsActive(section)

        AdjustmentAccordionSection(
            section: section,
            isExpanded: isExpanded,
            isEnabled: isEnabled,
            showsEnableToggle: section.isAdjustmentSection,
            isActive: isActive,
            onToggleExpanded: {
                let optionKey = NSEvent.modifierFlags.contains(.option)
                store.toggleSectionExpanded(section, optionKey: optionKey)
            },
            onToggleEnabled: { store.toggleSectionEnabled(section) },
            onReset: {
                let optionKey = NSEvent.modifierFlags.contains(.option)
                store.resetSection(section, optionKey: optionKey)
            },
            onCopySection: section.isAdjustmentSection ? { store.copySectionAdjustments(section) } : nil,
            onPasteSection: section.isAdjustmentSection ? { store.pasteSectionAdjustments() } : nil
        ) {
            switch section {
            case .histogram:
                HistogramSectionView(
                    histogram: store.activeHistogram,
                    readout: store.activePixelReadout,
                    referenceReadout: store.showsTwoPaneDeltaReadout ? store.referencePixelReadout : nil,
                    referenceLabel: store.histogramReferenceLabel,
                    profileName: metadata?.profileName,
                    sampleSize: presentation.pixelSampleSize,
                    displayMode: presentation.histogramDisplayMode,
                    deltaE: store.showsTwoPaneDeltaReadout ? store.activePixelDeltaE : nil,
                    emphasizeClipping: store.emphasizesClippingIndicators,
                    onSampleSizeChange: { size in
                        Task { @MainActor in
                            store.setPixelSampleSize(size)
                        }
                    },
                    onDisplayModeChange: { mode in
                        Task { @MainActor in
                            store.setHistogramDisplayMode(mode)
                        }
                    }
                )
            case .light:
                lightSectionContent
            case .toneCurve:
                toneCurveSectionContent
            case .color:
                colorSectionContent
            case .blackAndWhite:
                blackAndWhiteSectionContent
            case .presence:
                presenceSectionContent
            case .noise:
                noiseSectionContent
            case .optics:
                opticsSectionContent(pane: pane)
            case .geometry:
                geometrySectionContent
            case .compareMode:
                compareModeSectionContent
            case .metadata:
                metadataSectionContent(metadata: metadata, pane: pane)
            }
        }
    }

    private var lightSectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(L10n.string("light.auto_tone")) {
                store.autoLightToneFromActivePane()
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
            .disabled(store.activePane?.loadedImage == nil)

            slider(\.light.exposureEV, titleKey: "adjustments.exposure", range: -4...4, step: 0.05) {
                String(format: L10n.string("format.ev"), $0)
            }
            slider(\.light.brightness, titleKey: "adjustments.brightness", range: -0.5...0.5, step: 0.01) {
                String(format: "%.2f", $0)
            }
            slider(\.light.contrast, titleKey: "adjustments.contrast", range: 0.5...2.5, step: 0.01) {
                String(format: "%.2f", $0)
            }
            slider(\.light.highlights, titleKey: "adjustments.highlights", range: -100...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.light.shadows, titleKey: "adjustments.shadows", range: -100...100, step: 1) {
                String(format: "%.0f", $0)
            }
            clippingAwareSlider(\.light.whites, titleKey: "adjustments.whites", range: -100...100, step: 1) {
                String(format: "%.0f", $0)
            }
            clippingAwareSlider(\.light.blacks, titleKey: "adjustments.blacks", range: -100...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.light.gamma, titleKey: "adjustments.gamma", range: 0.4...2.5, step: 0.01) {
                String(format: "%.2f", $0)
            }
        }
    }

    private var toneCurveSectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(L10n.string("tone_curve.channel.label"), selection: $toneCurveChannel) {
                ForEach(ToneCurveChannel.allCases, id: \.self) { channel in
                    L10n.text(channel.titleKey).tag(channel)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Picker(L10n.string("tone_curve.preset.label"), selection: toneCurveBinding) {
                ForEach(ToneCurvePreset.allCases, id: \.self) { preset in
                    L10n.text(preset.titleKey).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .font(.caption)

            ToneCurveEditorView(
                points: toneCurvePointsBinding,
                showsCustomBadge: store.adjustments.toneCurve.usesCustomCurve(for: toneCurveChannel)
            )

            HStack(spacing: 6) {
                Button(L10n.string("tone_curve.reset_master")) {
                    store.resetToneCurveMaster()
                }
                Button(L10n.string("tone_curve.reset_rgb")) {
                    store.resetToneCurveRGB()
                }
            }
            .controlSize(.small)
        }
    }

    private var colorSectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button(L10n.string("color.reset_basic")) {
                    store.mutateAdjustments { $0.resetColorBasic() }
                }
                .controlSize(.small)

                Button(L10n.string("color.auto_balance")) {
                    store.autoBalanceColorFromActivePane()
                }
                .controlSize(.small)
                .disabled(store.activePane?.loadedImage == nil)
            }

            slider(\.color.temperature, titleKey: "adjustments.temperature", range: -100...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.color.tint, titleKey: "adjustments.tint", range: -100...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.color.vibrance, titleKey: "adjustments.vibrance", range: -100...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.color.saturationPercent, titleKey: "adjustments.saturation", range: 0...200, step: 1) {
                String(format: "%.0f%%", $0)
            }
            slider(\.color.hueShiftDegrees, titleKey: "adjustments.hue_shift", range: -180...180, step: 1) {
                String(format: "%.0f°", $0)
            }

            DisclosureGroup(isExpanded: $showsColorMixer) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Button(L10n.string("color_mixer.reset")) {
                            store.mutateAdjustments { $0.resetColorMixer() }
                        }
                        .controlSize(.small)
                    }

                    ForEach(ColorBandID.allCases, id: \.self) { band in
                        colorBandMixerControls(band)
                    }
                }
                .padding(.top, 4)
            } label: {
                L10n.text("color_mixer.title")
                    .font(.caption.weight(.semibold))
            }
        }
        .disabled(store.adjustments.blackAndWhite.monochromeCompare)
    }

    private func colorBandMixerControls(_ band: ColorBandID) -> some View {
        let hueBinding = colorMixerBinding(band: band, keyPath: \.hue)
        let satBinding = colorMixerBinding(band: band, keyPath: \.saturation)
        let lumBinding = colorMixerBinding(band: band, keyPath: \.luminance)

        return VStack(alignment: .leading, spacing: 4) {
            Text(L10n.string(band.titleKey))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            AdjustmentSliderRow(
                title: L10n.string("color_mixer.hue"),
                value: hueBinding,
                range: -100...100,
                step: 1,
                valueFormatter: { String(format: "%.0f", $0) },
                onLabelDoubleClick: { hueBinding.wrappedValue = 0 },
                onDragActiveChanged: { store.setAdjustmentDragActive($0) }
            )
            AdjustmentSliderRow(
                title: L10n.string("color_mixer.saturation"),
                value: satBinding,
                range: -100...100,
                step: 1,
                valueFormatter: { String(format: "%.0f", $0) },
                onLabelDoubleClick: { satBinding.wrappedValue = 0 },
                onDragActiveChanged: { store.setAdjustmentDragActive($0) }
            )
            AdjustmentSliderRow(
                title: L10n.string("color_mixer.luminance"),
                value: lumBinding,
                range: -100...100,
                step: 1,
                valueFormatter: { String(format: "%.0f", $0) },
                onLabelDoubleClick: { lumBinding.wrappedValue = 0 },
                onDragActiveChanged: { store.setAdjustmentDragActive($0) }
            )
        }
    }

    private func colorMixerBinding(
        band: ColorBandID,
        keyPath: WritableKeyPath<ColorBandMixer, Double>
    ) -> Binding<Double> {
        Binding(
            get: {
                store.adjustments.color.mixer.mixer(for: band)[keyPath: keyPath]
            },
            set: { newValue in
                store.mutateAdjustments { adjustments in
                    var mixer = adjustments.color.mixer.mixer(for: band)
                    mixer[keyPath: keyPath] = newValue
                    adjustments.color.mixer.setMixer(mixer, for: band)
                }
            }
        )
    }

    private var blackAndWhiteSectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            AdjustmentToggleRow(
                title: L10n.string("adjustments.monochrome"),
                isOn: Binding(
                    get: { store.adjustments.blackAndWhite.monochromeCompare },
                    set: { store.setMonochromeCompare($0) }
                )
            )

            if store.adjustments.blackAndWhite.monochromeCompare {
                Divider()
                HStack {
                    L10n.text("bw_mixer.title")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Button(L10n.string("bw_mixer.reset")) {
                        store.mutateAdjustments { $0.resetBlackAndWhiteMixer() }
                    }
                    .controlSize(.small)
                }

                ForEach(ColorBandID.allCases, id: \.self) { band in
                    AdjustmentSliderRow(
                        title: L10n.string(band.titleKey),
                        value: bwLuminanceBinding(band),
                        range: 0...200,
                        step: 1,
                        valueFormatter: { String(format: "%.0f", $0) },
                        onLabelDoubleClick: {
                            store.mutateAdjustments { $0.blackAndWhite.setLuminance(100, for: band) }
                        },
                        onDragActiveChanged: { store.setAdjustmentDragActive($0) }
                    )
                }
            }
        }
    }

    private func bwLuminanceBinding(_ band: ColorBandID) -> Binding<Double> {
        Binding(
            get: { store.adjustments.blackAndWhite.luminance(for: band) },
            set: { newValue in
                store.mutateAdjustments { $0.blackAndWhite.setLuminance(newValue, for: band) }
            }
        )
    }

    private var noiseSectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.activePaneIsBelowActualPixels {
                zoomHint
            }

            slider(\.noise.luminanceNR, titleKey: "adjustments.luminance_nr", range: 0...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.noise.luminanceDetail, titleKey: "adjustments.luminance_detail", range: 0...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.noise.luminanceContrast, titleKey: "adjustments.luminance_contrast", range: 0...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.noise.colorNR, titleKey: "adjustments.color_nr", range: 0...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.noise.colorDetail, titleKey: "adjustments.color_detail", range: 0...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.noise.colorSmoothness, titleKey: "adjustments.color_smoothness", range: 0...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.noise.defringePurple, titleKey: "adjustments.defringe_purple", range: 0...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.noise.defringeGreen, titleKey: "adjustments.defringe_green", range: 0...100, step: 1) {
                String(format: "%.0f", $0)
            }

            AdjustmentToggleRow(
                title: L10n.string("adjustments.noise_emphasis_preview"),
                isOn: Binding(
                    get: { store.adjustments.noise.noiseEmphasisPreview },
                    set: { store.setNoiseEmphasisPreview($0) }
                )
            )
        }
    }

    private func opticsSectionContent(pane: ImagePaneState?) -> some View {
        let hasLens = store.hasLensMetadata(for: pane)

        return VStack(alignment: .leading, spacing: 8) {
            if !hasLens {
                L10n.text("optics.no_lens_profile")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            AdjustmentToggleRow(
                title: L10n.string("adjustments.lens_profile"),
                isOn: boolBinding(\.optics.lensProfileCorrection)
            )
            .disabled(!hasLens)

            if hasLens {
                L10n.text("optics.lens_profile_estimate")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            slider(\.optics.distortionAmount, titleKey: "adjustments.distortion", range: -100...100, step: 1) {
                String(format: "%.0f", $0)
            }
            .disabled(!hasLens)

            slider(\.optics.vignettingAmount, titleKey: "adjustments.vignetting", range: -100...100, step: 1) {
                String(format: "%.0f", $0)
            }

            AdjustmentToggleRow(
                title: L10n.string("adjustments.chromatic_aberration"),
                isOn: boolBinding(\.optics.chromaticAberrationRemoval)
            )

            AdjustmentToggleRow(
                title: L10n.string("adjustments.flat_field"),
                isOn: boolBinding(\.optics.flatFieldCorrection)
            )

            L10n.text(store.hasLensMetadata(for: pane) ? "optics.flat_field_raw" : "optics.flat_field_standard")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var presenceSectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.activePaneIsBelowActualPixels {
                zoomHint
            }

            slider(\.presence.clarity, titleKey: "adjustments.clarity", range: -100...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.presence.texture, titleKey: "adjustments.texture", range: -100...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.presence.sharpenAmount, titleKey: "adjustments.sharpen_amount", range: 0...200, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.presence.sharpenRadius, titleKey: "adjustments.sharpen_radius", range: 0.5...3.0, step: 0.1) {
                String(format: "%.1f px", $0)
            }
            slider(\.presence.sharpenDetail, titleKey: "adjustments.sharpen_detail", range: 0...100, step: 1) {
                String(format: "%.0f", $0)
            }
            slider(\.presence.sharpenMasking, titleKey: "adjustments.sharpen_masking", range: 0...100, step: 1) {
                String(format: "%.0f", $0)
            }

            AdjustmentToggleRow(
                title: L10n.string("adjustments.edge_map_preview"),
                isOn: Binding(
                    get: { store.adjustments.presence.edgeMapPreview },
                    set: { value in
                        store.mutateAdjustments { $0.presence.edgeMapPreview = value }
                    }
                )
            )
        }
    }

    private var geometrySectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            slider(\.geometry.fineRotateDegrees, titleKey: "adjustments.fine_rotate", range: -5...5, step: 0.1) {
                String(format: "%.1f°", $0)
            }

            AdjustmentToggleRow(
                title: L10n.string("adjustments.flip_horizontal"),
                isOn: boolBinding(\.geometry.flipHorizontal)
            )
            AdjustmentToggleRow(
                title: L10n.string("adjustments.flip_vertical"),
                isOn: boolBinding(\.geometry.flipVertical)
            )

            AdjustmentToggleRow(
                title: L10n.string("adjustments.aspect_lock"),
                isOn: boolBinding(\.geometry.aspectLock)
            )

            AdjustmentToggleRow(
                title: L10n.string("adjustments.crop_overlay"),
                isOn: boolBinding(\.geometry.showCropOverlay)
            )

            if store.adjustments.geometry.showCropOverlay {
                Text(L10n.string("geometry.crop_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(L10n.string("geometry.reset_crop")) {
                    store.resetCropRect()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
    }

    private var compareModeSectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(L10n.string("compare.mode.label"), selection: compareModeBinding) {
                ForEach(CompareMode.cases(for: store.layout), id: \.self) { mode in
                    L10n.text(mode.titleKey).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .disabled(store.adjustments.blackAndWhite.monochromeCompare)

            if store.layout == .two, store.adjustments.compareMode.mode.requiresTwoPanes {
                Picker(L10n.string("compare.reference.label"), selection: referencePaneBinding) {
                    ForEach(CompareReferencePane.allCases, id: \.self) { pane in
                        L10n.text(pane.titleKey).tag(pane)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
            }

            if store.adjustments.compareMode.mode == .blink {
                slider(\.compareMode.blinkIntervalSeconds, titleKey: "compare.blink_interval", range: 0.25...2.0, step: 0.05) {
                    String(format: "%.2fs", $0)
                }
            }

            if store.adjustments.compareMode.mode == .wipe {
                L10n.text("compare.wipe_drag_hint")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                slider(\.compareMode.wipePosition, titleKey: "compare.wipe_position", range: 0...1, step: 0.01) {
                    String(format: "%.0f%%", $0 * 100)
                }
            }

            if usesAnalysisGain(store.adjustments.compareMode.mode) {
                slider(\.compareMode.analysisGain, titleKey: "compare.analysis_gain", range: 0.5...2.0, step: 0.05) {
                    String(format: "%.2f", $0)
                }
            }
        }
    }

    private var zoomHint: some View {
        HStack(spacing: 6) {
            L10n.text("adjustments.zoom_hint")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(L10n.string("adjustments.zoom_hint_action")) {
                store.actualPixels()
            }
            .controlSize(.small)
            .buttonStyle(.link)
        }
    }

    private func metadataSectionContent(metadata: ImageMetadata?, pane: ImagePaneState?) -> some View {
        Group {
            if let metadata {
                VStack(alignment: .leading, spacing: 5) {
                    inspectorRow(L10n.string("inspector.file"), metadata.fileName)
                    if let path = pane?.loadedImage?.url.path {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(L10n.string("inspector.path"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 78, alignment: .leading)

                            Text(path)
                                .font(.caption)
                                .lineLimit(2)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button(L10n.string("inspector.copy_path")) {
                                store.copyActivePanePathToPasteboard()
                            }
                            .controlSize(.small)
                            .buttonStyle(.borderless)
                        }
                    }
                    inspectorRow(L10n.string("inspector.type"), metadata.fileType)
                    inspectorRow(L10n.string("inspector.size"), metadata.dimensionsText)
                    inspectorRow(L10n.string("inspector.disk"), metadata.fileSizeText)
                    inspectorRow(L10n.string("inspector.color"), metadata.colorModel ?? L10n.string("common.unknown"))
                    inspectorRow(L10n.string("inspector.profile"), metadata.profileName ?? L10n.string("common.unknown"))
                    inspectorRow(
                        L10n.string("inspector.pipeline"),
                        metadata.usesRawPipeline
                            ? L10n.string("inspector.pipeline.raw_preview")
                            : L10n.string("inspector.pipeline.standard")
                    )
                    inspectorRow(L10n.string("inspector.zoom"), zoomText(for: pane?.viewport))
                    inspectorRow(L10n.string("inspector.rotation"), rotationText(for: pane?.viewport))
                    inspectorRow(
                        L10n.string("inspector.geometry_rotate"),
                        String(format: "%.1f°", store.adjustments.geometry.fineRotateDegrees)
                    )
                    inspectorRow(
                        L10n.string("inspector.compare_mode"),
                        L10n.string(store.adjustments.compareMode.mode.titleKey)
                    )
                    if store.adjustments.geometry.flipHorizontal || store.adjustments.geometry.flipVertical {
                        inspectorRow(
                            L10n.string("inspector.geometry_flip"),
                            geometryFlipSummary()
                        )
                    }
                    if store.adjustments.geometry.cropRectNormalized != GeometryAdjustments.defaultCropRect {
                        let crop = store.adjustments.geometry.cropRectNormalized
                        inspectorRow(
                            L10n.string("inspector.crop_rect"),
                            String(
                                format: "%.0f%% × %.0f%%",
                                crop.width * 100,
                                crop.height * 100
                            )
                        )
                    }
                }

                if !metadata.exifFields.isEmpty {
                    Divider()
                    L10n.text("inspector.exif")
                        .font(.caption.weight(.semibold))
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(metadata.exifFields) { field in
                            inspectorRow(L10n.string(field.labelKey), field.value)
                        }
                    }
                }
            } else {
                L10n.text("inspector.empty")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func inspectorRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
                .lineLimit(1)

            Text(value)
                .font(.caption)
                .lineLimit(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func slider(
        _ keyPath: WritableKeyPath<ComparisonAdjustments, Double>,
        titleKey: String,
        range: ClosedRange<Double>,
        step: Double,
        valueFormatter: @escaping (Double) -> String
    ) -> some View {
        AdjustmentSliderRow(
            title: L10n.string(titleKey),
            value: binding(keyPath),
            range: range,
            step: step,
            valueFormatter: valueFormatter,
            onLabelDoubleClick: {
                store.resetControl(keyPath)
            },
            onDragActiveChanged: { active in
                store.setAdjustmentDragActive(active)
            }
        )
    }

    private func clippingAwareSlider(
        _ keyPath: WritableKeyPath<ComparisonAdjustments, Double>,
        titleKey: String,
        range: ClosedRange<Double>,
        step: Double,
        valueFormatter: @escaping (Double) -> String
    ) -> some View {
        AdjustmentSliderRow(
            title: L10n.string(titleKey),
            value: binding(keyPath),
            range: range,
            step: step,
            valueFormatter: valueFormatter,
            onLabelDoubleClick: {
                store.resetControl(keyPath)
            },
            onDragActiveChanged: { active in
                store.setAdjustmentDragActive(active)
                store.setLightClippingPreviewActive(active)
            }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<ComparisonAdjustments, Double>) -> Binding<Double> {
        Binding(
            get: { store.adjustments[keyPath: keyPath] },
            set: { store.updateAdjustmentValue(keyPath, to: $0) }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<ComparisonAdjustments, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.adjustments[keyPath: keyPath] },
            set: { store.updateAdjustmentFlag(keyPath, to: $0) }
        )
    }

    private var bypassBinding: Binding<Bool> {
        Binding(
            get: { store.adjustments.inspector.bypassAllAdjustments },
            set: { store.setBypassAllAdjustments($0) }
        )
    }

    private var compareModeBinding: Binding<CompareMode> {
        Binding(
            get: { store.adjustments.compareMode.mode },
            set: { store.setCompareMode($0) }
        )
    }

    private var referencePaneBinding: Binding<CompareReferencePane> {
        Binding(
            get: { store.adjustments.compareMode.referencePane },
            set: { pane in
                store.mutateAdjustments { $0.compareMode.referencePane = pane }
            }
        )
    }

    private var toneCurveBinding: Binding<ToneCurvePreset> {
        Binding(
            get: { store.adjustments.toneCurve.preset(for: toneCurveChannel) },
            set: { store.setToneCurvePreset($0, channel: toneCurveChannel) }
        )
    }

    private var toneCurvePointsBinding: Binding<ToneCurvePoints> {
        Binding(
            get: { store.adjustments.toneCurve.resolvedPoints(for: toneCurveChannel) },
            set: { store.setToneCurveCustomPoints($0, channel: toneCurveChannel) }
        )
    }

    private func zoomText(for viewport: ViewportState?) -> String {
        guard let viewport else {
            return L10n.string("common.not_available")
        }

        return L10n.string("format.percent", Int(viewport.zoomScale * 100))
    }

    private func usesAnalysisGain(_ mode: CompareMode) -> Bool {
        switch mode {
        case .falseColor, .edgeMap, .noiseEmphasis, .absoluteDifference, .deltaE:
            true
        default:
            false
        }
    }

    private func geometryFlipSummary() -> String {
        let horizontal = store.adjustments.geometry.flipHorizontal
        let vertical = store.adjustments.geometry.flipVertical
        switch (horizontal, vertical) {
        case (true, true):
            return L10n.string("inspector.geometry_flip.both")
        case (true, false):
            return L10n.string("inspector.geometry_flip.horizontal")
        case (false, true):
            return L10n.string("inspector.geometry_flip.vertical")
        default:
            return L10n.string("common.not_available")
        }
    }

    private func rotationText(for viewport: ViewportState?) -> String {
        guard let viewport else {
            return L10n.string("common.not_available")
        }

        let degrees = viewport.rotationQuarterTurns * 90
        return L10n.string("format.degrees", degrees)
    }
}
