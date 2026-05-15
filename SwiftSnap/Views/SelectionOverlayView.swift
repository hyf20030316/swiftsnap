import Cocoa
import SwiftUI

/// A full-screen transparent overlay window for region selection
/// Uses NSWindow for proper fullscreen behavior and mouse event handling
class SelectionOverlayWindow: NSWindow {

    private var selectionView: SelectionView?
    private var startPoint: CGPoint?
    private var currentRect: CGRect = .zero
    private var onSelectionComplete: ((CGRect) -> Void)?
    private var onCancel: (() -> Void)?

    init(onSelectionComplete: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.onSelectionComplete = onSelectionComplete
        self.onCancel = onCancel

        // Get the main screen's frame
        let screenFrame = NSScreen.main?.frame ?? CGRect.zero

        // Create a fullscreen-style window
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window properties
        self.level = .screenSaver // Above everything
        self.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false

        // Create and set the selection view
        selectionView = SelectionView(frame: screenFrame)
        self.contentView = selectionView

        // Make the window visible on all spaces
        self.makeKeyAndOrderFront(nil)

        // Set up event monitoring
        setupEventMonitoring()
    }

    private func setupEventMonitoring() {
        // We'll handle mouse events in the selectionView directly
    }

    func startSelection() {
        startPoint = nil
        currentRect = .zero
        selectionView?.updateSelectionRect(.zero)
    }

    func handleMouseDown(at point: CGPoint) {
        startPoint = point
        currentRect = CGRect(origin: point, size: .zero)
        selectionView?.updateSelectionRect(currentRect)
    }

    func handleMouseDragged(at point: CGPoint) {
        guard let start = startPoint else { return }

        let width = abs(point.x - start.x)
        let height = abs(point.y - start.y)
        let originX = min(point.x, start.x)
        let originY = min(point.y, start.y)

        currentRect = CGRect(x: originX, y: originY, width: width, height: height)
        selectionView?.updateSelectionRect(currentRect)
    }

    func handleMouseUp() {
        // Ensure minimum selection size
        if currentRect.width > 10 && currentRect.height > 10 {
            onSelectionComplete?(currentRect)
        }
        closeWindow()
    }

    func handleEscape() {
        onCancel?()
        closeWindow()
    }

    private func closeWindow() {
        self.orderOut(nil)
        self.close()
    }
}

/// Custom NSView for drawing the selection rectangle
class SelectionView: NSView {

    private var selectionRect: CGRect = .zero
    private let borderWidth: CGFloat = 2.0

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !selectionRect.isEmpty else { return }

        // Draw dark overlay outside selection area
        let fullPath = NSBezierPath(rect: self.bounds)
        fullPath.append(NSBezierPath(rect: selectionRect).reversed)
        NSColor.black.withAlphaComponent(0.5).setFill()
        fullPath.fill()

        // Draw selection border
        let borderPath = NSBezierPath(rect: selectionRect)
        borderPath.lineWidth = borderWidth
        NSColor.systemBlue.setStroke()
        borderPath.stroke()

        // Draw corner handles
        drawCornerHandles()

        // Draw size indicator
        drawSizeIndicator()
    }

    func updateSelectionRect(_ rect: CGRect) {
        selectionRect = rect
        needsDisplay = true
    }

    private func drawCornerHandles() {
        let handleSize: CGFloat = 8.0
        let corners = [
            CGPoint(x: selectionRect.minX, y: selectionRect.minY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.minY),
            CGPoint(x: selectionRect.minX, y: selectionRect.maxY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.maxY)
        ]

        NSColor.systemBlue.setFill()
        for corner in corners {
            let handleRect = CGRect(
                x: corner.x - handleSize/2,
                y: corner.y - handleSize/2,
                width: handleSize,
                height: handleSize
            )
            NSBezierPath(rect: handleRect).fill()
        }
    }

    private func drawSizeIndicator() {
        guard selectionRect.width > 50 && selectionRect.height > 50 else { return }

        let widthText = "\(Int(selectionRect.width))"
        let heightText = "\(Int(selectionRect.height))"
        let sizeText = "\(widthText) × \(heightText)"

        let font = NSFont.systemFont(ofSize: 14)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let textSize = sizeText.size(withAttributes: attrs)
        let textRect = CGRect(
            x: selectionRect.midX - textSize.width/2,
            y: selectionRect.minY - textSize.height - 8,
            width: textSize.width,
            height: textSize.height
        )

        // Draw background for text
        let bgRect = textRect.insetBy(dx: -4, dy: -2)
        NSColor.systemBlue.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4).fill()

        // Draw text
        sizeText.draw(at: textRect.origin, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        (self.window as? SelectionOverlayWindow)?.handleMouseDown(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        (self.window as? SelectionOverlayWindow)?.handleMouseDragged(at: point)
    }

    override func mouseUp(with event: NSEvent) {
        (self.window as? SelectionOverlayWindow)?.handleMouseUp()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            (self.window as? SelectionOverlayWindow)?.handleEscape()
        }
    }
}