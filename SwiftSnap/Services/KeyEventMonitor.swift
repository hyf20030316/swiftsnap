import Cocoa
import Carbon

/// Monitors keyboard events to detect double-tap Option key
/// Uses CGEventTap (requires Accessibility permission)
class KeyEventMonitor {

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastOptionPressTime: Date?
    private let doubleTapThreshold: TimeInterval

    /// Callback when double-tap Option is detected
    var onDoubleTapOption: (() -> Void)?

    init(doubleTapThreshold: TimeInterval = NSEvent.doubleClickInterval) {
        self.doubleTapThreshold = doubleTapThreshold
    }

    /// Start monitoring keyboard events
    /// Returns false if Accessibility permission is not granted
    func start() -> Bool {
        // Check if we have Accessibility permission
        let trusted = AXIsProcessTrusted()
        if !trusted {
            // Request permission
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            return false
        }

        // Create event tap - listen to flagsChanged for modifier keys
        let eventsOfInterest = CGEventMask(1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventsOfInterest,
            callback: { proxy, type, event, refcon in
                return KeyEventMonitor.handleEvent(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return false
        }

        self.eventTap = tap

        // Add to run loop
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)

        print("KeyEventMonitor started")
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        print("KeyEventMonitor stopped")
    }

    /// Handle keyboard event callback
    private static func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent,
        refcon: UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>? {
        guard let refcon = refcon else {
            return Unmanaged.passRetained(event)
        }

        let monitor = Unmanaged<KeyEventMonitor>.fromOpaque(refcon).takeUnretainedValue()

        // For flagsChanged events, check if Option key was pressed
        if type == .flagsChanged {
            let flags = event.flags
            let optionPressed = flags.contains(.maskAlternate)

            // keyCode 58 = Left Option, 61 = Right Option
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if (keyCode == 58 || keyCode == 61) && optionPressed {
                monitor.handleOptionKeyPress()
            }
        }

        // Pass event through
        return Unmanaged.passRetained(event)
    }

    private func handleOptionKeyPress() {
        let now = Date()

        if let lastTime = lastOptionPressTime {
            let interval = now.timeIntervalSince(lastTime)
            if interval < doubleTapThreshold {
                // Double-tap detected!
                lastOptionPressTime = nil
                onDoubleTapOption?()
            } else {
                // Too slow, start new detection
                lastOptionPressTime = now
            }
        } else {
            // First press
            lastOptionPressTime = now
        }
    }
}