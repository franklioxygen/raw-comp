import SwiftUI

struct ContentView: View {
    @StateObject private var store = WorkspaceStore()

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar(store: store)
            Divider()
            HSplitView {
                ComparisonGridView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if store.showInspector {
                    InspectorView(store: store)
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
                }
            }
            Divider()
            HStack {
                Text(store.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(store.linkMode == .synced ? "Viewport Sync On" : "Viewport Sync Off")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .underPageBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

                Text("Inspector")
                    .font(.headline)

                if let metadata {
                    VStack(alignment: .leading, spacing: 5) {
                        inspectorRow("File", metadata.fileName)
                        inspectorRow("Type", metadata.fileType)
                        inspectorRow("Size", metadata.dimensionsText)
                        inspectorRow("Disk", metadata.fileSizeText)
                        inspectorRow("Color", metadata.colorModel ?? "Unknown")
                        inspectorRow("Profile", metadata.profileName ?? "Unknown")
                        inspectorRow("Pipeline", metadata.usesRawPipeline ? "RAW / Preview" : "Standard")
                        inspectorRow("Zoom", zoomText(for: pane?.viewport))
                        inspectorRow("Rotation", rotationText(for: pane?.viewport))
                    }

                    if !metadata.exifFields.isEmpty {
                        Divider()
                        Text("EXIF")
                            .font(.subheadline.weight(.semibold))
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(metadata.exifFields) { field in
                                inspectorRow(field.label, field.value)
                            }
                        }
                    }
                } else {
                    Text("Select a pane with an image to inspect file details and viewport state.")
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
                    Text("Comparison Adjustments")
                        .font(.title3.weight(.semibold))
                    Text("Applied to every loaded image pane.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Reset") {
                    store.resetAdjustments()
                }
                .disabled(store.adjustments.isNeutral)
            }

            AdjustmentSliderRow(
                title: "Exposure",
                value: binding(\.exposureEV),
                range: -2...2,
                step: 0.05,
                valueFormatter: { String(format: "%.2f EV", $0) }
            )

            AdjustmentSliderRow(
                title: "Brightness",
                value: binding(\.brightness),
                range: -0.4...0.4,
                step: 0.01,
                valueFormatter: { String(format: "%.2f", $0) }
            )

            AdjustmentSliderRow(
                title: "Contrast",
                value: binding(\.contrast),
                range: 0.5...2.5,
                step: 0.01,
                valueFormatter: { String(format: "%.2f", $0) }
            )

            AdjustmentSliderRow(
                title: "Saturation",
                value: binding(\.saturation),
                range: 0...2,
                step: 0.01,
                valueFormatter: { String(format: "%.2f", $0) }
            )

            AdjustmentSliderRow(
                title: "Detail",
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
            return "n/a"
        }

        return "\(Int(viewport.zoomScale * 100))%"
    }

    private func rotationText(for viewport: ViewportState?) -> String {
        guard let viewport else {
            return "n/a"
        }

        let degrees = viewport.rotationQuarterTurns * 90
        return "\(degrees) degrees"
    }

    private func binding(_ keyPath: WritableKeyPath<ComparisonAdjustments, Double>) -> Binding<Double> {
        Binding(
            get: { store.adjustments[keyPath: keyPath] },
            set: { store.adjustments[keyPath: keyPath] = $0 }
        )
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

            Slider(value: value, in: range, step: step)
        }
    }
}
