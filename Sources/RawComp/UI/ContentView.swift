import SwiftUI

struct ContentView: View {
    @StateObject private var store = WorkspaceStore()
    @ObservedObject var settingsController: AppSettingsController
    @State private var showingAdvancedSettings = false

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar(
                store: store,
                onOpenAdvancedSettings: { showingAdvancedSettings = true }
            )
            Divider()
            HSplitView {
                ComparisonGridView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if store.showInspector {
                    InspectorView(store: store)
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
                }
            }
        }
        .id(settingsController.language.rawValue)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: settingsController.language) {
            store.refreshLocalization()
        }
        .sheet(isPresented: $showingAdvancedSettings) {
            AdvancedSettingsView(settingsController: settingsController)
        }
    }
}

private struct InspectorView: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        let pane = store.activePane
        let metadata = pane?.loadedImage?.metadata

        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                adjustmentSection

                Divider()

                L10n.text("inspector.title")
                    .font(.headline)

                if let metadata {
                    VStack(alignment: .leading, spacing: 5) {
                        inspectorRow(L10n.string("inspector.file"), metadata.fileName)
                        inspectorRow(L10n.string("inspector.type"), metadata.fileType)
                        inspectorRow(L10n.string("inspector.size"), metadata.dimensionsText)
                        inspectorRow(L10n.string("inspector.disk"), metadata.fileSizeText)
                        inspectorRow(L10n.string("inspector.color"), metadata.colorModel ?? L10n.string("common.unknown"))
                        inspectorRow(L10n.string("inspector.profile"), metadata.profileName ?? L10n.string("common.unknown"))
                        inspectorRow(L10n.string("inspector.pipeline"), metadata.usesRawPipeline ? L10n.string("inspector.pipeline.raw_preview") : L10n.string("inspector.pipeline.standard"))
                        inspectorRow(L10n.string("inspector.zoom"), zoomText(for: pane?.viewport))
                        inspectorRow(L10n.string("inspector.rotation"), rotationText(for: pane?.viewport))
                    }

                    if !metadata.exifFields.isEmpty {
                        Divider()
                        L10n.text("inspector.exif")
                            .font(.subheadline.weight(.semibold))
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(metadata.exifFields) { field in
                                inspectorRow(L10n.string(field.labelKey), field.value)
                            }
                        }
                    }
                } else {
                    L10n.text("inspector.empty")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var adjustmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    L10n.text("adjustments.title")
                        .font(.title3.weight(.semibold))
                    L10n.text("adjustments.subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(L10n.string("common.reset")) {
                    store.resetAdjustments()
                }
                .disabled(store.adjustments.isNeutral)
            }

            AdjustmentSliderRow(
                title: L10n.string("adjustments.exposure"),
                value: binding(\.exposureEV),
                range: -2...2,
                step: 0.05,
                valueFormatter: { String(format: L10n.string("format.ev"), $0) }
            )

            AdjustmentSliderRow(
                title: L10n.string("adjustments.brightness"),
                value: binding(\.brightness),
                range: -0.4...0.4,
                step: 0.01,
                valueFormatter: { String(format: "%.2f", $0) }
            )

            AdjustmentSliderRow(
                title: L10n.string("adjustments.contrast"),
                value: binding(\.contrast),
                range: 0.5...2.5,
                step: 0.01,
                valueFormatter: { String(format: "%.2f", $0) }
            )

            AdjustmentSliderRow(
                title: L10n.string("adjustments.saturation"),
                value: binding(\.saturation),
                range: 0...2,
                step: 0.01,
                valueFormatter: { String(format: "%.2f", $0) }
            )

            AdjustmentSliderRow(
                title: L10n.string("adjustments.detail"),
                value: binding(\.sharpness),
                range: 0...2,
                step: 0.01,
                valueFormatter: { String(format: "%.2f", $0) }
            )

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

    private func zoomText(for viewport: ViewportState?) -> String {
        guard let viewport else {
            return L10n.string("common.not_available")
        }

        return L10n.string("format.percent", Int(viewport.zoomScale * 100))
    }

    private func rotationText(for viewport: ViewportState?) -> String {
        guard let viewport else {
            return L10n.string("common.not_available")
        }

        let degrees = viewport.rotationQuarterTurns * 90
        return L10n.string("format.degrees", degrees)
    }

    private func binding(_ keyPath: WritableKeyPath<ComparisonAdjustments, Double>) -> Binding<Double> {
        Binding(
            get: { store.adjustments[keyPath: keyPath] },
            set: { store.adjustments[keyPath: keyPath] = $0 }
        )
    }
}

private struct AdvancedSettingsView: View {
    @ObservedObject var settingsController: AppSettingsController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            L10n.text("settings.title")
                .font(.title2.weight(.semibold))

            Form {
                Picker(L10n.string("settings.appearance"), selection: $settingsController.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        L10n.text(theme.titleKey).tag(theme)
                    }
                }

                Picker(L10n.string("settings.language"), selection: $settingsController.language) {
                    ForEach(AppLanguage.allCases) { language in
                        L10n.text(language.titleKey).tag(language)
                    }
                }

                Toggle(
                    L10n.string("settings.autoupdate"),
                    isOn: Binding(
                        get: { settingsController.autoUpdateEnabled },
                        set: { settingsController.setAutoUpdateEnabled($0) }
                    )
                )
                .disabled(!settingsController.canManageAutoUpdate)

                HStack {
                    L10n.text("settings.manual_update")
                    Spacer()
                    Button(L10n.string("settings.check_updates"), action: settingsController.checkForUpdates)
                        .disabled(!settingsController.canCheckForUpdates)
                }
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 6) {
                Text(settingsController.canManageAutoUpdate
                    ? L10n.string("settings.footer.available")
                    : L10n.string("settings.footer.unavailable"))
                Text(L10n.string("settings.version", AppVersion.marketingVersion, AppVersion.buildNumber))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button(L10n.string("common.done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}

private struct AdjustmentSliderRow: View {
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let valueFormatter: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(valueFormatter(value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: steppedValue, in: range)
        }
    }

    private var steppedValue: Binding<Double> {
        Binding(
            get: { value.wrappedValue },
            set: { newValue in
                let stepped = (newValue / step).rounded() * step
                value.wrappedValue = min(max(stepped, range.lowerBound), range.upperBound)
            }
        )
    }
}
