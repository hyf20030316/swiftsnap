import ScreenCaptureKit
import Cocoa

/// Handles screen capture using ScreenCaptureKit (macOS 13+)
class ScreenCaptureService {

    /// Capture a specific region of the screen
    /// Returns the captured image or nil if failed
    func captureRegion(rect: CGRect) async throws -> CGImage? {
        // Get shareable content (displays and windows)
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        // Get the main display
        guard let display = content.displays.first else {
            print("No displays found")
            return nil
        }

        // Get the scale factor for Retina displays
        let scaleFactor = getScaleFactor(for: display)

        // Create content filter for the display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Create stream configuration with actual pixel dimensions
        let config = SCStreamConfiguration()
        config.width = Int(rect.width * scaleFactor)
        config.height = Int(rect.height * scaleFactor)
        config.sourceRect = rect

        // Capture single frame
        let image = try await captureImage(filter: filter, config: config)
        return image
    }

    /// Capture the entire display at full resolution
    func captureDisplay() async throws -> CGImage? {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = content.displays.first else {
            print("No displays found")
            return nil
        }

        // Get the scale factor for Retina displays
        let scaleFactor = getScaleFactor(for: display)

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()

        // Use display's native resolution (actual pixels, not logical points)
        let displayFrame = display.frame
        config.width = Int(displayFrame.width * scaleFactor)
        config.height = Int(displayFrame.height * scaleFactor)
        config.sourceRect = displayFrame

        let image = try await captureImage(filter: filter, config: config)
        return image
    }

    /// Get the scale factor for a display (handles Retina displays)
    private func getScaleFactor(for display: SCDisplay) -> CGFloat {
        // Try to get the native scale factor from ScreenCaptureKit
        // The display's frame is in points, but we need actual pixels
        // For Retina displays, this is typically 2.0
        if let mainScreen = NSScreen.main {
            return mainScreen.backingScaleFactor
        }
        // Fallback: assume Retina (2x) if we can't determine
        return 2.0
    }

    /// Capture a single frame from SCStream
    private func captureImage(filter: SCContentFilter, config: SCStreamConfiguration) async throws -> CGImage {
        // For macOS 14+, use SCScreenshotManager
        if #available(macOS 14.0, *) {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        }

        // For macOS 13, use CGDisplayCreateImage with proper resolution
        let mainDisplay = CGMainDisplayID()
        let sourceRect = config.sourceRect

        // Get actual pixel dimensions for Retina
        let pixelsWide = CGDisplayPixelsWide(mainDisplay)
        let pixelsHigh = CGDisplayPixelsHigh(mainDisplay)
        let displayBounds = CGRect(x: 0, y: 0, width: pixelsWide, height: pixelsHigh)

        // Create image at full resolution
        guard let image = CGDisplayCreateImage(mainDisplay, rect: sourceRect.isEmpty ? displayBounds : sourceRect) else {
            throw ScreenCaptureError.captureFailed
        }
        return image
    }

    /// Save image to file
    func saveImage(_ image: CGImage, to path: String, format: ImageFormat = .png) -> Bool {
        let url = URL(fileURLWithPath: path)
        let destination = CGImageDestinationCreateWithURL(url as CFURL, format.contentType, 1, nil)

        guard let dest = destination else {
            print("Failed to create image destination")
            return false
        }

        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)

        print("Image saved to: \(path) (\(image.width)x\(image.height) pixels)")
        return true
    }

    /// Copy image to clipboard
    func copyToClipboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        pasteboard.writeObjects([nsImage])
        print("Image copied to clipboard (\(image.width)x\(image.height) pixels)")
    }
}

enum ImageFormat {
    case png
    case jpeg

    var contentType: CFString {
        switch self {
        case .png:
            return kUTTypePNG
        case .jpeg:
            return kUTTypeJPEG
        }
    }
}

enum ScreenCaptureError: Error {
    case noDisplay
    case noPermission
    case captureFailed
}