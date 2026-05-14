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

        // Create content filter for the display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Create stream configuration
        let config = SCStreamConfiguration()
        config.width = Int(rect.width)
        config.height = Int(rect.height)
        config.sourceRect = rect

        // Capture single frame
        let image = try await captureImage(filter: filter, config: config)
        return image
    }

    /// Capture the entire display
    func captureDisplay() async throws -> CGImage? {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = content.displays.first else {
            print("No displays found")
            return nil
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()

        // Use display's native resolution
        let displayFrame = display.frame
        config.width = Int(displayFrame.width)
        config.height = Int(displayFrame.height)
        config.sourceRect = displayFrame

        let image = try await captureImage(filter: filter, config: config)
        return image
    }

    /// Capture a single frame from SCStream
    private func captureImage(filter: SCContentFilter, config: SCStreamConfiguration) async throws -> CGImage {
        // For macOS 13+, we can use SCScreenshotManager for single frame capture
        // This is simpler than setting up a full stream

        #if swift(>=5.9)
        // macOS 14+ has SCScreenshotManager
        if #available(macOS 14.0, *) {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        }
        #endif

        // For macOS 13, we need to use SCStream with a single-frame handler
        // This is a workaround - in production, we'd set up a proper stream
        // For the spike, we'll use CGWindowListCopyWindowInfo as fallback

        // Fallback: use CGDisplayCreateImage
        guard let mainDisplay = CGMainDisplayID() as CGDirectDisplayID? else {
            throw ScreenCaptureError.noDisplay
        }

        let image = CGDisplayCreateImage(mainDisplay, rect: config.sourceRect)
        return image!
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

        print("Image saved to: \(path)")
        return true
    }

    /// Copy image to clipboard
    func copyToClipboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        pasteboard.writeObjects([nsImage])
        print("Image copied to clipboard")
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