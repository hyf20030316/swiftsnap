import SwiftUI
import Combine

@main
struct SwiftSnapApp: App {
    @StateObject private var appDelegate = AppDelegate()

    var body: some Scene {
        WindowGroup {
            EmptyView()
                .onAppear {
                    appDelegate.startMonitoring()
                }
        }
        .defaultSize(width: 300, height: 350)
    }
}

/// AppDelegate handles background operations
class AppDelegate: ObservableObject {
    private var keyMonitor: KeyEventMonitor?
    private var captureService: ScreenCaptureService?
    private var selectionWindow: SelectionOverlayWindow?

    func startMonitoring() {
        keyMonitor = KeyEventMonitor()
        captureService = ScreenCaptureService()

        keyMonitor?.onDoubleTapOption = { [weak self] in
            self?.handleDoubleTapOption()
        }

        let started = keyMonitor?.start() ?? false
        if !started {
            print("⚠️ Accessibility permission required - please grant in System Settings > Privacy & Security > Accessibility")
        }
    }

    func stopMonitoring() {
        keyMonitor?.stop()
    }

    private func handleDoubleTapOption() {
        print("📸 Starting region selection...")

        // Show selection overlay
        selectionWindow = SelectionOverlayWindow(
            onSelectionComplete: { [weak self] rect in
                self?.captureRegion(rect: rect)
            },
            onCancel: {
                print("📸 Selection cancelled")
            }
        )

        // Make the window accept key events
        selectionWindow?.makeKeyAndOrderFront(nil)
    }

    private func captureRegion(rect: CGRect) {
        print("📸 Capturing region: \(rect)")

        // Convert NSView coordinates to CGDisplay coordinates
        // NSView uses flipped coordinates (y=0 at bottom)
        // CGDisplay uses unflipped coordinates (y=0 at top)
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let cgRect = CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        Task {
            do {
                let image = try await captureService?.captureRegion(rect: cgRect)
                if let img = image {
                    // Save to Desktop
                    let timestamp = DateFormatter.filenameFormat.string(from: Date())
                    let path = "~/Desktop/SwiftSnap_\(timestamp).png"
                        .replacingOccurrences(of: "~", with: NSHomeDirectory())

                    _ = captureService?.saveImage(img, to: path)
                    captureService?.copyToClipboard(img)
                }
            } catch {
                print("❌ Capture failed: \(error)")
            }
        }
    }
}

extension DateFormatter {
    static var filenameFormat: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }
}

/// Empty view for Settings scene placeholder
struct EmptyView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("SwiftSnap")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Double-tap Option to select region")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Label("macOS 13+ required", systemImage: "info.circle")
                Label("Accessibility permission needed", systemImage: "hand.raised")
                Label("Screen Recording permission needed", systemImage: "rectangle.on.rectangle")
            }
            .font(.caption)

            Divider()

            Text("🚧 MVP Phase — Region selection")
                .font(.caption2)
                .foregroundColor(.orange)
        }
        .padding(40)
        .frame(width: 300, height: 350)
    }
}