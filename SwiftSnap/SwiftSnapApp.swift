import SwiftUI

@main
struct SwiftSnapApp: App {
    @StateObject private var appDelegate = AppDelegate()

    var body: some Scene {
        // This app runs in background, no main window needed for spike
        Settings {
            EmptyView()
        }
    }
}

/// AppDelegate handles background operations
class AppDelegate: ObservableObject {
    private var keyMonitor: KeyEventMonitor?
    private var captureService: ScreenCaptureService?

    func startMonitoring() {
        keyMonitor = KeyEventMonitor()
        captureService = ScreenCaptureService()

        keyMonitor?.onDoubleTapOption = { [weak self] in
            self?.handleDoubleTapOption()
        }

        let started = keyMonitor?.start() ?? false
        if !started {
            print("⚠️ Accessibility permission required")
            // TODO: Show permission dialog
        }
    }

    func stopMonitoring() {
        keyMonitor?.stop()
    }

    private func handleDoubleTapOption() {
        print("📸 Triggering screenshot...")

        // For spike: capture entire screen
        Task {
            do {
                let image = try await captureService?.captureDisplay()
                if let img = image {
                    // Save to Desktop
                    let timestamp = DateFormatter.filenameFormat.string(from: Date())
                    let path = "~/Desktop/SpikeScreenshot_\(timestamp).png"
                        .replacingOccurrences(of: "~", with: NSHomeDirectory())

                    captureService?.saveImage(img, to: path)

                    // Also copy to clipboard
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

            Text("Double-tap Option to capture")
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

            Text("🚧 Spike Phase — Testing keyboard monitoring")
                .font(.caption2)
                .foregroundColor(.orange)
        }
        .padding(40)
        .frame(width: 300, height: 350)
    }
}