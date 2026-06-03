import SwiftUI

struct HistogramSectionView: View {
    let histogram: ImageHistogram?
    let readout: PixelReadout?
    let referenceReadout: PixelReadout?
    let referenceLabel: String?
    let profileName: String?
    let sampleSize: PixelSampleSize
    let displayMode: HistogramDisplayMode
    let deltaE: Double?
    let emphasizeClipping: Bool
    let onSampleSizeChange: (PixelSampleSize) -> Void
    let onDisplayModeChange: (HistogramDisplayMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(L10n.string("histogram.display.label"), selection: Binding(
                get: { displayMode },
                set: { onDisplayModeChange($0) }
            )) {
                ForEach(HistogramDisplayMode.allCases, id: \.self) { mode in
                    L10n.text(mode.titleKey).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HistogramChartView(histogram: histogram, displayMode: displayMode)
                .frame(height: 72)

            HStack(spacing: 10) {
                clipBadge(
                    title: L10n.string("histogram.clip.highlight"),
                    isClipping: histogram?.hasHighlightClipping == true,
                    color: .red,
                    emphasized: emphasizeClipping
                )
                clipBadge(
                    title: L10n.string("histogram.clip.shadow"),
                    isClipping: histogram?.hasShadowClipping == true,
                    color: .blue,
                    emphasized: emphasizeClipping
                )
            }

            Picker(L10n.string("histogram.sample.label"), selection: Binding(
                get: { sampleSize },
                set: { onSampleSizeChange($0) }
            )) {
                ForEach(PixelSampleSize.allCases, id: \.self) { size in
                    L10n.text(size.titleKey).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if let readout, readout != .empty {
                VStack(alignment: .leading, spacing: 4) {
                    if let referenceReadout, referenceReadout != .empty {
                        readoutRow(
                            referenceLabel ?? L10n.string("histogram.readout.reference"),
                            referenceReadout.rgbText
                        )
                        readoutRow(L10n.string("histogram.readout.active"), readout.rgbText)
                    } else {
                        readoutRow(L10n.string("histogram.readout.rgb"), readout.rgbText)
                    }
                    readoutRow(L10n.string("histogram.readout.luma"), "\(readout.luma)")
                    readoutRow(L10n.string("histogram.readout.position"), readout.coordinatesText)
                    if let deltaE {
                        readoutRow(L10n.string("histogram.readout.delta_e"), String(format: "%.2f", deltaE))
                    }
                }
            } else {
                L10n.text("histogram.readout.empty")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let profileName {
                inspectorCaption(L10n.string("histogram.profile"), profileName)
            } else {
                inspectorCaption(
                    L10n.string("histogram.profile"),
                    L10n.string("common.unknown")
                )
            }
        }
    }

    private func readoutRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(.caption2.monospacedDigit())
        }
    }

    private func clipBadge(title: String, isClipping: Bool, color: Color, emphasized: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isClipping || emphasized ? color : Color.secondary.opacity(0.35))
                .frame(width: emphasized ? 10 : 8, height: emphasized ? 10 : 8)
                .shadow(color: emphasized ? color.opacity(0.65) : .clear, radius: 4)
            Text(title)
                .font(emphasized ? .caption.weight(.semibold) : .caption2)
                .foregroundStyle(emphasized || isClipping ? color : .secondary)
        }
        .padding(.horizontal, emphasized ? 4 : 0)
        .padding(.vertical, emphasized ? 2 : 0)
        .background(
            emphasized
                ? color.opacity(0.12)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 4)
        )
    }

    private func inspectorCaption(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2)
                .lineLimit(1)
        }
    }
}

private struct HistogramChartView: View {
    let histogram: ImageHistogram?
    let displayMode: HistogramDisplayMode

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.08))

                if let histogram {
                    switch displayMode {
                    case .rgb:
                        histogramLayer(
                            bins: histogram.red,
                            color: .red.opacity(0.55),
                            size: geometry.size
                        )
                        histogramLayer(
                            bins: histogram.green,
                            color: .green.opacity(0.45),
                            size: geometry.size
                        )
                        histogramLayer(
                            bins: histogram.blue,
                            color: .blue.opacity(0.5),
                            size: geometry.size
                        )
                        histogramLayer(
                            bins: histogram.luma,
                            color: .primary.opacity(0.25),
                            size: geometry.size,
                            lineWidth: 1
                        )
                    case .luma:
                        histogramLayer(
                            bins: histogram.luma,
                            color: .primary.opacity(0.85),
                            size: geometry.size,
                            lineWidth: 1.5
                        )
                    }
                }
            }
        }
    }

    private func histogramLayer(
        bins: [Int],
        color: Color,
        size: CGSize,
        lineWidth: CGFloat = 0
    ) -> some View {
        let maxCount = max(bins.max() ?? 1, 1)
        return Path { path in
            guard size.width > 1, size.height > 1 else {
                return
            }

            for index in 0..<bins.count {
                let x = (CGFloat(index) / 255) * size.width
                let height = (CGFloat(bins[index]) / CGFloat(maxCount)) * size.height
                let y = size.height - height
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(color, lineWidth: lineWidth == 0 ? 1 : lineWidth)
    }
}
