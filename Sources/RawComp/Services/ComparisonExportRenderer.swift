import AppKit
import CoreGraphics
import Foundation

enum ComparisonExportRenderer {
    static func renderGrid(
        panes: [(title: String, image: CGImage)],
        columns: Int,
        spacing: Int = 4,
        includeLabels: Bool = true
    ) -> CGImage? {
        guard !panes.isEmpty, columns > 0 else {
            return nil
        }

        let scaled = panes.map { pane -> (title: String, image: CGImage, size: CGSize) in
            let image = pane.image
            let size = CGSize(width: max(image.width, 1), height: max(image.height, 1))
            return (pane.title, image, size)
        }

        let targetRowHeight = scaled.map(\.size.height).max() ?? 1
        let rows = (scaled.count + columns - 1) / columns

        var rowWidths: [CGFloat] = Array(repeating: 0, count: rows)
        let rowHeights: [CGFloat] = Array(repeating: targetRowHeight, count: rows)

        for (index, item) in scaled.enumerated() {
            let row = index / columns
            let scale = targetRowHeight / item.size.height
            let width = item.size.width * scale
            rowWidths[row] += width
            if index % columns != columns - 1 && index < scaled.count - 1 {
                rowWidths[row] += CGFloat(spacing)
            }
        }

        let labelHeight: CGFloat = includeLabels ? 22 : 0
        let canvasWidth = Int(rowWidths.max() ?? 0) + (spacing * 2)
        let imageStackHeight = rowHeights.reduce(0, +)
        let labelStackHeight = labelHeight * CGFloat(rows)
        let verticalSpacing = CGFloat(spacing * max(0, rows - 1))
        let canvasHeight = Int(imageStackHeight + labelStackHeight + verticalSpacing) + (spacing * 2)

        guard canvasWidth > 0, canvasHeight > 0 else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard
            let context = CGContext(
                data: nil,
                width: canvasWidth,
                height: canvasHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        context.setFillColor(CGColor.black)
        context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

        // Flip to a top-left origin so CGImage data renders right-side up.
        context.translateBy(x: 0, y: CGFloat(canvasHeight))
        context.scaleBy(x: 1, y: -1)

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
                let imageRect = CGRect(x: xOffset, y: yOffset + labelHeight, width: drawWidth, height: drawHeight)

                context.interpolationQuality = CGInterpolationQuality.high
                context.draw(item.image, in: imageRect)

                if includeLabels {
                    let labelRect = CGRect(x: xOffset, y: yOffset, width: drawWidth, height: labelHeight)
                    drawLabel(item.title, in: labelRect, context: context)
                }

                xOffset += drawWidth + CGFloat(spacing)
            }

            yOffset += rowHeight + labelHeight + CGFloat(spacing)
        }

        return context.makeImage()
    }

    private static func drawLabel(_ title: String, in labelRect: CGRect, context: CGContext) {
        context.setFillColor(CGColor(gray: 0.12, alpha: 1))
        context.fill(labelRect)

        // Restore normal (non-flipped) coordinates for AppKit text rendering.
        context.saveGState()
        context.translateBy(x: 0, y: labelRect.maxY + labelRect.minY)
        context.scaleBy(x: 1, y: -1)
        let localRect = CGRect(x: labelRect.minX, y: 0, width: labelRect.width, height: labelRect.height)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = (title as NSString).size(withAttributes: attributes)
        let origin = CGPoint(
            x: localRect.minX + 6,
            y: localRect.midY - (size.height / 2)
        )
        (title as NSString).draw(at: origin, withAttributes: attributes)
        context.restoreGState()
    }
}
