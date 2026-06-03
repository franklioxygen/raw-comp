import AppKit
import SwiftUI

struct ImageCanvasView: NSViewRepresentable {
    let loadedImage: LoadedImage
    let displayCGImage: CGImage
    let viewport: ViewportState
    let highlightRect: CGRect?
    let showCropOverlay: Bool
    let cropRectNormalized: CGRect
    let allowsCropEditing: Bool
    let locksCropAspect: Bool
    let onViewportChange: (ViewportState) -> Void
    let onSelect: () -> Void
    var onCropRectChange: ((CGRect) -> Void)?
    var onImageCursorMove: ((CGPoint) -> Void)?

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
            documentView.onImageCursorMove = { [weak coordinator = context.coordinator] point in
                coordinator?.onImageCursorMove?(point)
            }
            scrollView.documentView = documentView

        context.coordinator.attach(to: scrollView, documentView: documentView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onViewportChange = onViewportChange
        context.coordinator.onSelect = onSelect
        context.coordinator.onImageCursorMove = onImageCursorMove
        context.coordinator.update(
            scrollView: scrollView,
            loadedImage: loadedImage,
            displayCGImage: displayCGImage,
            viewport: viewport,
            highlightRect: highlightRect,
            showCropOverlay: showCropOverlay,
            cropRectNormalized: cropRectNormalized,
            allowsCropEditing: allowsCropEditing,
            locksCropAspect: locksCropAspect,
            onCropRectChange: onCropRectChange
        )
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.detach()
        scrollView.documentView = nil
    }

    @MainActor
    final class Coordinator: NSObject {
        private struct PendingViewportApplication {
            let viewport: ViewportState
            let documentSize: CGSize
            let imageChanged: Bool
        }

        var onViewportChange: (ViewportState) -> Void
        var onSelect: () -> Void
        var onImageCursorMove: ((CGPoint) -> Void)?

        private weak var scrollView: NSScrollView?
        private weak var documentView: ImageDocumentView?
        private var observers: [NSObjectProtocol] = []
        private var isApplyingState = false
        private var lastImageURL: URL?
        private var pendingViewportApplication: PendingViewportApplication?
        private var viewportApplicationScheduled = false

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
            highlightRect: CGRect?,
            showCropOverlay: Bool,
            cropRectNormalized: CGRect,
            allowsCropEditing: Bool,
            locksCropAspect: Bool,
            onCropRectChange: ((CGRect) -> Void)?
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
            documentView.showCropOverlay = showCropOverlay
            documentView.cropRectNormalized = cropRectNormalized.clampedUnit()
            documentView.allowsCropEditing = allowsCropEditing
            documentView.locksCropAspect = locksCropAspect
            documentView.onCropRectChange = onCropRectChange
            documentView.displayScale = viewport.zoomScale
            let documentSize = documentView.updateDocumentSize()

            pendingViewportApplication = PendingViewportApplication(
                viewport: viewport.clamped(),
                documentSize: documentSize,
                imageChanged: imageChanged
            )
            scheduleViewportApplication()
        }

        private func scheduleViewportApplication() {
            guard !viewportApplicationScheduled else {
                return
            }

            viewportApplicationScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                self.viewportApplicationScheduled = false
                guard
                    let pending = self.pendingViewportApplication,
                    let scrollView = self.scrollView
                else {
                    return
                }

                self.pendingViewportApplication = nil
                self.applyViewport(
                    pending.viewport,
                    to: scrollView,
                    documentSize: pending.documentSize,
                    imageChanged: pending.imageChanged
                )
            }
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
            let viewport = ViewportState(
                zoomMode: .manual,
                zoomScale: scrollView.magnification,
                normalizedCenter: normalizedCenter,
                visibleRectNormalized: normalizedVisible,
                rotationQuarterTurns: documentView.rotationQuarterTurns
            )
            DispatchQueue.main.async { [onViewportChange] in
                onViewportChange(viewport)
            }
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
    var showCropOverlay = false
    var cropRectNormalized = GeometryAdjustments.defaultCropRect
    var allowsCropEditing = false
    var locksCropAspect = true
    var onCropRectChange: ((CGRect) -> Void)?
    var displayScale: CGFloat = 1
    var onImageCursorMove: ((CGPoint) -> Void)?

    private var lastDragLocationInWindow: NSPoint?
    private var cropDragStartNormalized: CGPoint?
    private var cropDragPreviewRect: CGRect?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }

        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseMoved(with event: NSEvent) {
        reportCursor(at: event)
    }

    func updateDocumentSize() -> CGSize {
        let normalizedTurns = abs(rotationQuarterTurns % 2)
        let size = normalizedTurns == 1
            ? CGSize(width: max(imageSize.height, 1), height: max(imageSize.width, 1))
            : CGSize(width: max(imageSize.width, 1), height: max(imageSize.height, 1))
        if frame.size != size {
            setFrameSize(size)
        }
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

        if showCropOverlay {
            drawCompositionOverlay(in: drawRect)
            let crop = (cropDragPreviewRect ?? cropRectNormalized).clampedUnit()
            drawCropOverlay(in: drawRect, cropNormalized: crop)
        }

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
        if allowsCropEditing, showCropOverlay, event.modifierFlags.contains(.option) {
            cropDragStartNormalized = normalizedImagePoint(from: convert(event.locationInWindow, from: nil))
            cropDragPreviewRect = cropRectNormalized
            lastDragLocationInWindow = nil
            reportCursor(at: event)
            return
        }

        lastDragLocationInWindow = event.locationInWindow
        reportCursor(at: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if
            allowsCropEditing,
            showCropOverlay,
            let start = cropDragStartNormalized,
            let end = normalizedImagePoint(from: convert(event.locationInWindow, from: nil))
        {
            cropDragPreviewRect = cropRect(from: start, to: end)
            needsDisplay = true
            return
        }

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
        if let cropDragPreviewRect {
            onCropRectChange?(cropDragPreviewRect.clampedUnit())
        }

        cropDragStartNormalized = nil
        cropDragPreviewRect = nil
        lastDragLocationInWindow = nil
    }

    private func reportCursor(at event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard let normalized = normalizedImagePoint(from: location) else {
            return
        }

        DispatchQueue.main.async { [onImageCursorMove, normalized] in
            onImageCursorMove?(normalized)
        }
    }

    private func normalizedImagePoint(from documentPoint: CGPoint) -> CGPoint? {
        let centerX = bounds.midX
        let centerY = bounds.midY
        var local = CGPoint(x: documentPoint.x - centerX, y: documentPoint.y - centerY)

        let radians = -CGFloat(rotationQuarterTurns * 90) * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        local = CGPoint(
            x: local.x * cosine - local.y * sine,
            y: local.x * sine + local.y * cosine
        )

        let width = max(imageSize.width, 1)
        let height = max(imageSize.height, 1)
        let normalizedX = (local.x + width / 2) / width
        let normalizedY = 1 - ((local.y + height / 2) / height)

        guard normalizedX >= 0, normalizedX <= 1, normalizedY >= 0, normalizedY <= 1 else {
            return nil
        }

        return CGPoint(x: normalizedX, y: normalizedY)
    }

    private func drawCropOverlay(in drawRect: CGRect, cropNormalized: CGRect) {
        let cropRect = CGRect(
            x: drawRect.minX + (cropNormalized.minX * drawRect.width),
            y: drawRect.minY + (cropNormalized.minY * drawRect.height),
            width: cropNormalized.width * drawRect.width,
            height: cropNormalized.height * drawRect.height
        )

        let dimAlpha: CGFloat = 0.42
        NSColor.black.withAlphaComponent(dimAlpha).setFill()

        if cropRect.minY > drawRect.minY {
            NSBezierPath(rect: CGRect(x: drawRect.minX, y: drawRect.minY, width: drawRect.width, height: cropRect.minY - drawRect.minY)).fill()
        }
        if cropRect.maxY < drawRect.maxY {
            NSBezierPath(rect: CGRect(x: drawRect.minX, y: cropRect.maxY, width: drawRect.width, height: drawRect.maxY - cropRect.maxY)).fill()
        }
        if cropRect.minX > drawRect.minX {
            NSBezierPath(rect: CGRect(x: drawRect.minX, y: cropRect.minY, width: cropRect.minX - drawRect.minX, height: cropRect.height)).fill()
        }
        if cropRect.maxX < drawRect.maxX {
            NSBezierPath(rect: CGRect(x: cropRect.maxX, y: cropRect.minY, width: drawRect.maxX - cropRect.maxX, height: cropRect.height)).fill()
        }

        NSColor.systemYellow.setStroke()
        let path = NSBezierPath(rect: cropRect)
        path.lineWidth = max(1.5, 2.5 / max(displayScale, 0.001))
        path.stroke()
    }

    private func cropRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        var rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        guard locksCropAspect, imageSize.width > 0, imageSize.height > 0 else {
            return rect.clampedUnit()
        }

        let aspect = imageSize.width / imageSize.height
        if rect.width / max(rect.height, 0.0001) > aspect {
            rect.size.height = rect.width / aspect
        } else {
            rect.size.width = rect.height * aspect
        }

        if end.x < start.x {
            rect.origin.x = start.x - rect.width
        }
        if end.y < start.y {
            rect.origin.y = start.y - rect.height
        }

        return rect.clampedUnit()
    }

    private func drawCompositionOverlay(in drawRect: CGRect) {
        NSColor.white.withAlphaComponent(0.42).setStroke()
        let lineWidth = max(0.75, 1.25 / max(displayScale, 0.001))

        for fraction in [1.0 / 3.0, 2.0 / 3.0] {
            let vertical = NSBezierPath()
            let x = drawRect.minX + (drawRect.width * fraction)
            vertical.move(to: CGPoint(x: x, y: drawRect.minY))
            vertical.line(to: CGPoint(x: x, y: drawRect.maxY))
            vertical.lineWidth = lineWidth
            vertical.stroke()

            let horizontal = NSBezierPath()
            let y = drawRect.minY + (drawRect.height * fraction)
            horizontal.move(to: CGPoint(x: drawRect.minX, y: y))
            horizontal.line(to: CGPoint(x: drawRect.maxX, y: y))
            horizontal.lineWidth = lineWidth
            horizontal.stroke()
        }

        NSColor.white.withAlphaComponent(0.2).setStroke()
        let border = NSBezierPath(rect: drawRect.insetBy(dx: 1, dy: 1))
        border.lineWidth = lineWidth
        border.stroke()
    }

    private func drawPlaceholder(in rect: CGRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let text = NSAttributedString(
            string: L10n.string("canvas.placeholder"),
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
