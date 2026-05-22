import AppKit
import SwiftUI

struct ImageCanvasView: NSViewRepresentable {
    let loadedImage: LoadedImage
    let displayCGImage: CGImage
    let viewport: ViewportState
    let highlightRect: CGRect?
    let onViewportChange: (ViewportState) -> Void
    let onSelect: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onViewportChange: onViewportChange, onSelect: onSelect)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.05
        scrollView.maxMagnification = 20.0
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.contentView.postsBoundsChangedNotifications = true

        let documentView = ImageDocumentView()
        documentView.owningScrollView = scrollView
        documentView.onSelect = context.coordinator.handleSelection
        scrollView.documentView = documentView

        context.coordinator.attach(to: scrollView, documentView: documentView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onViewportChange = onViewportChange
        context.coordinator.onSelect = onSelect
        context.coordinator.update(
            scrollView: scrollView,
            loadedImage: loadedImage,
            displayCGImage: displayCGImage,
            viewport: viewport,
            highlightRect: highlightRect
        )
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.detach()
        scrollView.documentView = nil
    }

    @MainActor
    final class Coordinator: NSObject {
        var onViewportChange: (ViewportState) -> Void
        var onSelect: () -> Void

        private weak var scrollView: NSScrollView?
        private weak var documentView: ImageDocumentView?
        private var observers: [NSObjectProtocol] = []
        private var isApplyingState = false
        private var lastImageURL: URL?

        init(onViewportChange: @escaping (ViewportState) -> Void, onSelect: @escaping () -> Void) {
            self.onViewportChange = onViewportChange
            self.onSelect = onSelect
        }

        func handleSelection() {
            onSelect()
        }

        fileprivate func attach(to scrollView: NSScrollView, documentView: ImageDocumentView) {
            self.scrollView = scrollView
            self.documentView = documentView

            let center = NotificationCenter.default
            observers = [
                center.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: scrollView.contentView,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.reportViewportChange()
                    }
                },
                center.addObserver(
                    forName: NSScrollView.didEndLiveMagnifyNotification,
                    object: scrollView,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.reportViewportChange()
                    }
                },
                center.addObserver(
                    forName: NSScrollView.didEndLiveScrollNotification,
                    object: scrollView,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.reportViewportChange()
                    }
                }
            ]
        }

        fileprivate func detach() {
            let center = NotificationCenter.default
            for observer in observers {
                center.removeObserver(observer)
            }
            observers.removeAll()
        }

        func update(
            scrollView: NSScrollView,
            loadedImage: LoadedImage,
            displayCGImage: CGImage,
            viewport: ViewportState,
            highlightRect: CGRect?
        ) {
            guard let documentView = scrollView.documentView as? ImageDocumentView else {
                return
            }

            let imageChanged = lastImageURL != loadedImage.url
            lastImageURL = loadedImage.url

            documentView.image = NSImage(
                cgImage: displayCGImage,
                size: NSSize(width: displayCGImage.width, height: displayCGImage.height)
            )
            documentView.imageSize = CGSize(width: displayCGImage.width, height: displayCGImage.height)
            documentView.rotationQuarterTurns = viewport.rotationQuarterTurns
            documentView.highlightRectNormalized = highlightRect?.clampedUnit()
            documentView.displayScale = viewport.zoomScale
            let documentSize = documentView.updateDocumentSize()

            applyViewport(
                viewport.clamped(),
                to: scrollView,
                documentSize: documentSize,
                imageChanged: imageChanged
            )
        }

        private func applyViewport(
            _ viewport: ViewportState,
            to scrollView: NSScrollView,
            documentSize: CGSize,
            imageChanged: Bool
        ) {
            guard
                documentSize.width > 0,
                documentSize.height > 0,
                let documentView = documentView
            else {
                return
            }

            isApplyingState = true
            defer { isApplyingState = false }

            let desiredCenter = CGPoint(
                x: viewport.normalizedCenter.x * documentSize.width,
                y: viewport.normalizedCenter.y * documentSize.height
            )

            let desiredScale: CGFloat
            switch viewport.zoomMode {
            case .fit:
                desiredScale = fitScale(documentSize: documentSize, clipSize: scrollView.contentView.bounds.size)
            case .actual:
                desiredScale = 1.0
            case .manual:
                desiredScale = viewport.zoomScale
            }

            let clampedScale = min(max(desiredScale, scrollView.minMagnification), scrollView.maxMagnification)
            if imageChanged || abs(scrollView.magnification - clampedScale) > 0.001 {
                scrollView.setMagnification(clampedScale, centeredAt: desiredCenter)
            }

            documentView.displayScale = clampedScale
            let visibleRect = scrollView.documentVisibleRect
            let targetOrigin = CGPoint(
                x: clamp(desiredCenter.x - (visibleRect.width / 2), lower: 0, upper: max(documentSize.width - visibleRect.width, 0)),
                y: clamp(desiredCenter.y - (visibleRect.height / 2), lower: 0, upper: max(documentSize.height - visibleRect.height, 0))
            )

            if pointsDiffer(scrollView.contentView.bounds.origin, targetOrigin, tolerance: 0.5) {
                scrollView.contentView.scroll(to: targetOrigin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }

        private func reportViewportChange() {
            guard
                !isApplyingState,
                let scrollView,
                let documentView
            else {
                return
            }

            let bounds = documentView.bounds
            guard bounds.width > 0, bounds.height > 0 else {
                return
            }

            let visible = scrollView.documentVisibleRect
            let normalizedCenter = CGPoint(
                x: clamp(visible.midX / bounds.width, lower: 0, upper: 1),
                y: clamp(visible.midY / bounds.height, lower: 0, upper: 1)
            )
            let normalizedVisible = CGRect(
                x: clamp(visible.minX / bounds.width, lower: 0, upper: 1),
                y: clamp(visible.minY / bounds.height, lower: 0, upper: 1),
                width: min(max(visible.width / bounds.width, 0), 1),
                height: min(max(visible.height / bounds.height, 0), 1)
            ).clampedUnit()

            documentView.displayScale = scrollView.magnification
            onViewportChange(
                ViewportState(
                    zoomMode: .manual,
                    zoomScale: scrollView.magnification,
                    normalizedCenter: normalizedCenter,
                    visibleRectNormalized: normalizedVisible,
                    rotationQuarterTurns: documentView.rotationQuarterTurns
                )
            )
        }

        private func fitScale(documentSize: CGSize, clipSize: CGSize) -> CGFloat {
            guard documentSize.width > 0, documentSize.height > 0 else {
                return 1
            }

            return min(clipSize.width / documentSize.width, clipSize.height / documentSize.height)
        }

        private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
            min(max(value, lower), upper)
        }

        private func pointsDiffer(_ lhs: CGPoint, _ rhs: CGPoint, tolerance: CGFloat) -> Bool {
            abs(lhs.x - rhs.x) > tolerance || abs(lhs.y - rhs.y) > tolerance
        }
    }
}

fileprivate final class ImageDocumentView: NSView {
    weak var owningScrollView: NSScrollView?
    var onSelect: () -> Void = {}
    var image: NSImage?
    var imageSize = CGSize(width: 1, height: 1)
    var rotationQuarterTurns = 0
    var highlightRectNormalized: CGRect?
    var displayScale: CGFloat = 1

    private var lastDragLocationInWindow: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func updateDocumentSize() -> CGSize {
        let normalizedTurns = abs(rotationQuarterTurns % 2)
        let size = normalizedTurns == 1
            ? CGSize(width: max(imageSize.height, 1), height: max(imageSize.width, 1))
            : CGSize(width: max(imageSize.width, 1), height: max(imageSize.height, 1))
        setFrameSize(size)
        needsDisplay = true
        return size
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        guard let image else {
            drawPlaceholder(in: dirtyRect)
            return
        }

        let drawSize = CGSize(width: max(imageSize.width, 1), height: max(imageSize.height, 1))
        let drawRect = CGRect(
            x: -drawSize.width / 2,
            y: -drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX, yBy: bounds.midY)
        transform.rotate(byDegrees: CGFloat(rotationQuarterTurns * 90))
        transform.concat()

        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)

        if let highlightRectNormalized, highlightRectNormalized.width > 0, highlightRectNormalized.height > 0 {
            let overlayRect = CGRect(
                x: drawRect.minX + (highlightRectNormalized.minX * drawRect.width),
                y: drawRect.minY + (highlightRectNormalized.minY * drawRect.height),
                width: highlightRectNormalized.width * drawRect.width,
                height: highlightRectNormalized.height * drawRect.height
            )

            NSColor.systemYellow.setStroke()
            let path = NSBezierPath(rect: overlayRect)
            path.lineWidth = max(1.5, 3.0 / max(displayScale, 0.001))
            path.stroke()
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    override func mouseDown(with event: NSEvent) {
        onSelect()
        lastDragLocationInWindow = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard
            let scrollView = owningScrollView,
            let lastDragLocationInWindow
        else {
            return
        }

        let nextLocationInWindow = event.locationInWindow
        let delta = CGPoint(
            x: nextLocationInWindow.x - lastDragLocationInWindow.x,
            y: nextLocationInWindow.y - lastDragLocationInWindow.y
        )
        let visibleRect = scrollView.documentVisibleRect
        let targetOrigin = CGPoint(
            x: min(max(visibleRect.origin.x - delta.x, 0), max(bounds.width - visibleRect.width, 0)),
            y: min(max(visibleRect.origin.y + delta.y, 0), max(bounds.height - visibleRect.height, 0))
        )
        scrollView.contentView.scroll(to: targetOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        self.lastDragLocationInWindow = nextLocationInWindow
    }

    override func mouseUp(with event: NSEvent) {
        lastDragLocationInWindow = nil
    }

    private func drawPlaceholder(in rect: CGRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let text = NSAttributedString(
            string: "Load an image to begin comparing.",
            attributes: [
                .font: NSFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        let size = text.size()
        let origin = CGPoint(
            x: rect.midX - (size.width / 2),
            y: rect.midY - (size.height / 2)
        )
        text.draw(at: origin)
    }
}
