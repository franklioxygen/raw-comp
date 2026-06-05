import AppKit
import CoreGraphics
import Foundation

enum ComparisonExportRenderer {
    struct Pane {
        let title: String
        let topInfoLines: [String]
        let image: CGImage
        let exifSummary: String?
    }

    static func renderGrid(
        panes: [Pane],
        columns: Int,
        canvasSize: CGSize? = nil,
        spacing: Int = 4,
        includeLabels: Bool = true,
        includeTopInfoBar: Bool = false,
        includeBottomInfoBar: Bool = false
    ) -> CGImage? {
        guard !panes.isEmpty, columns > 0 else {
            return nil
        }

        if let canvasSize, canvasSize.width > 0, canvasSize.height > 0 {
            return renderFixedCanvasGrid(
                panes: panes,
                columns: columns,
                canvasSize: canvasSize,
                spacing: spacing,
                includeLabels: includeLabels,
                includeTopInfoBar: includeTopInfoBar,
                includeBottomInfoBar: includeBottomInfoBar
            )
        }

        return renderIntrinsicGrid(
            panes: panes,
            columns: columns,
            spacing: spacing,
            includeLabels: includeLabels,
            includeTopInfoBar: includeTopInfoBar,
            includeBottomInfoBar: includeBottomInfoBar
        )
    }

    private static func renderIntrinsicGrid(
        panes: [Pane],
        columns: Int,
        spacing: Int,
        includeLabels: Bool,
        includeTopInfoBar: Bool,
        includeBottomInfoBar: Bool
    ) -> CGImage? {
        let scaled = panes.map { pane -> (pane: Pane, size: CGSize) in
            let image = pane.image
            let size = CGSize(width: max(image.width, 1), height: max(image.height, 1))
            return (pane, size)
        }

        let targetRowHeight = scaled.map(\.size.height).max() ?? 1
        let rows = (scaled.count + columns - 1) / columns
        var rowWidths: [CGFloat] = Array(repeating: 0, count: rows)
        let rowHeights: [CGFloat] = Array(repeating: targetRowHeight, count: rows)
        let labelHeight: CGFloat = includeLabels ? 22 : 0

        for (index, item) in scaled.enumerated() {
            let row = index / columns
            let scale = targetRowHeight / item.size.height
            let width = item.size.width * scale
            rowWidths[row] += width
            if index % columns != columns - 1 && index < scaled.count - 1 {
                rowWidths[row] += CGFloat(spacing)
            }
        }

        let canvasWidth = Int(rowWidths.max() ?? 0) + (spacing * 2)
        let imageStackHeight = rowHeights.reduce(0, +)
        let labelStackHeight = labelHeight * CGFloat(rows)
        let verticalSpacing = CGFloat(spacing * max(0, rows - 1))
        let canvasHeight = Int(imageStackHeight + labelStackHeight + verticalSpacing) + (spacing * 2)

        guard canvasWidth > 0, canvasHeight > 0 else {
            return nil
        }

        return renderBitmap(pixelsWide: canvasWidth, pixelsHigh: canvasHeight) { _ in
            var yOffset = CGFloat(spacing)
            for row in 0..<rows {
                var xOffset = CGFloat(spacing)
                let rowHeight = rowHeights[row]

                for column in 0..<columns {
                    let index = (row * columns) + column
                    guard index < scaled.count else {
                        break
                    }

                    let item = scaled[index]
                    let scale = rowHeight / item.size.height
                    let drawWidth = item.size.width * scale
                    let drawHeight = rowHeight
                    let imageRect = NSRect(
                        x: xOffset,
                        y: yOffset + labelHeight,
                        width: drawWidth,
                        height: drawHeight
                    )

                    drawPaneImage(item.pane.image, in: imageRect)
                    drawInfoBarOverlays(
                        for: item.pane,
                        in: imageRect,
                        includeTopInfoBar: includeTopInfoBar,
                        includeBottomInfoBar: includeBottomInfoBar
                    )

                    if includeLabels {
                        let labelRect = NSRect(x: xOffset, y: yOffset, width: drawWidth, height: labelHeight)
                        drawLabel(item.pane.title, in: labelRect)
                    }

                    xOffset += drawWidth + CGFloat(spacing)
                }

                yOffset += rowHeight + labelHeight + CGFloat(spacing)
            }
        }
    }

    private static func renderFixedCanvasGrid(
        panes: [Pane],
        columns: Int,
        canvasSize: CGSize,
        spacing: Int,
        includeLabels: Bool,
        includeTopInfoBar: Bool,
        includeBottomInfoBar: Bool
    ) -> CGImage? {
        let rows = (panes.count + columns - 1) / columns
        let labelHeight: CGFloat = includeLabels ? 22 : 0
        let verticalSpacing = CGFloat(spacing * max(0, rows - 1))
        let horizontalSpacing = CGFloat(spacing * max(0, columns - 1))
        let canvasWidth = max(Int(canvasSize.width.rounded(.down)), 0)
        let canvasHeight = max(Int(canvasSize.height.rounded(.down)), 0)

        guard canvasWidth > 0, canvasHeight > 0 else {
            return nil
        }

        return renderBitmap(pixelsWide: canvasWidth, pixelsHigh: canvasHeight) { canvasRect in
            let availableWidth = canvasRect.width - horizontalSpacing
            let availableHeight = canvasRect.height - verticalSpacing
            guard availableWidth > 0, availableHeight > 0 else {
                return
            }

            let cellWidth = availableWidth / CGFloat(columns)
            let cellHeight = availableHeight / CGFloat(rows)
            let resolvedLabelHeight = includeLabels ? min(labelHeight, max(cellHeight - 1, 0)) : 0

            var yOffset = CGFloat(0)
            for row in 0..<rows {
                var xOffset = CGFloat(0)

                for column in 0..<columns {
                    let index = (row * columns) + column
                    guard index < panes.count else {
                        break
                    }

                    let pane = panes[index]
                    let paneRect = NSRect(
                        x: xOffset,
                        y: yOffset,
                        width: cellWidth,
                        height: cellHeight
                    )

                    NSColor.black.setFill()
                    NSBezierPath.fill(paneRect)

                    let imageCanvasRect = NSRect(
                        x: paneRect.minX,
                        y: paneRect.minY + resolvedLabelHeight,
                        width: paneRect.width,
                        height: max(paneRect.height - resolvedLabelHeight, 0)
                    )
                    let fittedImageRect = aspectFitRect(
                        for: CGSize(width: pane.image.width, height: pane.image.height),
                        in: imageCanvasRect
                    )
                    drawPaneImage(pane.image, in: fittedImageRect)
                    drawInfoBarOverlays(
                        for: pane,
                        in: imageCanvasRect,
                        includeTopInfoBar: includeTopInfoBar,
                        includeBottomInfoBar: includeBottomInfoBar
                    )

                    if includeLabels {
                        let labelRect = NSRect(
                            x: paneRect.minX,
                            y: paneRect.minY,
                            width: paneRect.width,
                            height: resolvedLabelHeight
                        )
                        drawLabel(pane.title, in: labelRect)
                    }

                    xOffset += cellWidth + CGFloat(spacing)
                }

                yOffset += cellHeight + CGFloat(spacing)
            }
        }
    }

    private static func renderBitmap(
        pixelsWide: Int,
        pixelsHigh: Int,
        draw: (NSRect) -> Void
    ) -> CGImage? {
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelsWide,
                pixelsHigh: pixelsHigh,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            return nil
        }

        bitmap.size = NSSize(width: pixelsWide, height: pixelsHigh)
        guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high

        let canvasRect = NSRect(x: 0, y: 0, width: pixelsWide, height: pixelsHigh)
        NSColor.black.setFill()
        NSBezierPath.fill(canvasRect)
        draw(canvasRect)

        NSGraphicsContext.restoreGraphicsState()
        return bitmap.cgImage
    }

    private static func aspectFitRect(for imageSize: CGSize, in bounds: NSRect) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }

        let widthScale = bounds.width / imageSize.width
        let heightScale = bounds.height / imageSize.height
        let scale = min(widthScale, heightScale)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return NSRect(
            x: bounds.midX - (fittedSize.width / 2),
            y: bounds.midY - (fittedSize.height / 2),
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    private static func drawPaneImage(_ cgImage: CGImage, in rect: NSRect) {
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        image.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
    }

    private static func drawInfoBarOverlays(
        for pane: Pane,
        in imageRect: NSRect,
        includeTopInfoBar: Bool,
        includeBottomInfoBar: Bool
    ) {
        // NSBitmapImageRep contexts use a bottom-left origin (isFlipped == false).
        if includeTopInfoBar, !pane.topInfoLines.isEmpty {
            let barHeight = topInfoBarHeight(for: pane.topInfoLines, imageHeight: imageRect.height)
            let barRect = NSRect(
                x: imageRect.minX,
                y: imageRect.maxY - barHeight,
                width: imageRect.width,
                height: barHeight
            )
            drawGradientBar(in: barRect, strongEdge: .top)
            drawTopInfoText(lines: pane.topInfoLines, in: barRect.insetBy(dx: 14, dy: 12))
        }

        if includeBottomInfoBar, let exifSummary = pane.exifSummary {
            let barHeight = bottomInfoBarHeight(for: exifSummary, width: imageRect.width, imageHeight: imageRect.height)
            let barRect = NSRect(
                x: imageRect.minX,
                y: imageRect.minY,
                width: imageRect.width,
                height: barHeight
            )
            drawGradientBar(in: barRect, strongEdge: .bottom)
            drawBottomInfoText(exifSummary, in: barRect.insetBy(dx: 10, dy: 6))
        }
    }

    private static func drawLabel(_ title: String, in labelRect: NSRect) {
        NSColor(white: 0.12, alpha: 1).setFill()
        NSBezierPath.fill(labelRect)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = (title as NSString).size(withAttributes: attributes)
        let origin = NSPoint(
            x: labelRect.minX + 6,
            y: labelRect.midY - (size.height / 2)
        )
        (title as NSString).draw(at: origin, withAttributes: attributes)
    }

    private enum StrongEdge {
        case top
        case bottom
    }

    private static func drawGradientBar(in rect: NSRect, strongEdge: StrongEdge) {
        let steps = 24
        let stepHeight = rect.height / CGFloat(steps)
        for step in 0..<steps {
            let progress = CGFloat(step) / CGFloat(max(steps - 1, 1))
            let alpha: CGFloat
            if progress < 0.35 {
                alpha = 0.72
            } else if progress < 0.7 {
                alpha = 0.38
            } else {
                alpha = 0.0
            }

            let y: CGFloat
            switch strongEdge {
            case .top:
                y = rect.maxY - (CGFloat(step + 1) * stepHeight)
            case .bottom:
                y = rect.minY + (CGFloat(step) * stepHeight)
            }

            NSColor(white: 0, alpha: alpha).setFill()
            NSBezierPath.fill(NSRect(x: rect.minX, y: y, width: rect.width, height: stepHeight + 1))
        }
    }

    private static func drawTopInfoText(lines: [String], in textRect: NSRect) {
        var y = textRect.maxY
        for (index, line) in lines.enumerated() {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: index == 0 ? NSFont.systemFont(ofSize: 13, weight: .semibold) : NSFont.systemFont(ofSize: 11),
                .foregroundColor: index == 0 ? NSColor.white : NSColor.white.withAlphaComponent(0.78)
            ]
            let size = (line as NSString).size(withAttributes: attributes)
            y -= size.height
            (line as NSString).draw(at: NSPoint(x: textRect.minX, y: y), withAttributes: attributes)
            y -= 2
        }
    }

    private static func drawBottomInfoText(_ text: String, in textRect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        (text as NSString).draw(
            with: textRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
    }

    private static func bottomInfoBarHeight(for text: String, width: CGFloat, imageHeight: CGFloat) -> CGFloat {
        let contentWidth = max(width - 20, 40)
        let maxHeight = min(max(imageHeight * 0.3, 42), 120)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        ]
        let textBounds = (text as NSString).boundingRect(
            with: NSSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        return min(max(ceil(textBounds.height) + 12, 30), maxHeight)
    }

    private static func topInfoBarHeight(for lines: [String], imageHeight: CGFloat) -> CGFloat {
        guard !lines.isEmpty else {
            return min(imageHeight * 0.18, 72)
        }

        var totalHeight: CGFloat = 0
        for (index, line) in lines.enumerated() {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: index == 0 ? NSFont.systemFont(ofSize: 13, weight: .semibold) : NSFont.systemFont(ofSize: 11)
            ]
            totalHeight += ceil((line as NSString).size(withAttributes: attributes).height)
            if index < lines.count - 1 {
                totalHeight += 2
            }
        }

        return min(max(totalHeight + 24, 36), 120)
    }
}
