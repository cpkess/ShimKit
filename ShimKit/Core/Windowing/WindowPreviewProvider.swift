import AppKit
import ScreenCaptureKit

@MainActor
final class WindowPreviewProvider {
    private var task: Task<Void, Never>?
    private var generation = UUID()

    func begin(windows: [WindowInfo], deliver: @escaping (WindowKey, NSImage) -> Void) {
        end()
        guard Preferences.shared.previews, CGPreflightScreenCaptureAccess() else { return }
        let session = generation
        task = Task { [weak self] in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
                // AX has no public window-ID accessor. Match conservatively; ambiguous windows keep their icons.
                for window in windows.prefix(24) where !window.minimized {
                    guard !Task.isCancelled, self?.generation == session else { return }
                    let candidates = content.windows.filter {
                        $0.owningApplication?.processID == window.pid && $0.windowLayer == 0 &&
                        WindowGeometry.approximatelyEqual($0.frame, window.frame, tolerance: 5)
                    }
                    let titled = candidates.filter { $0.title == window.title }
                    let matches = titled.isEmpty ? candidates : titled
                    guard matches.count == 1, let captureWindow = matches.first else { continue }
                    let filter = SCContentFilter(desktopIndependentWindow: captureWindow)
                    let config = SCStreamConfiguration()
                    let scale = min(384 / max(1, window.frame.width), 240 / max(1, window.frame.height))
                    config.width = max(1, Int(window.frame.width * scale))
                    config.height = max(1, Int(window.frame.height * scale))
                    config.showsCursor = false
                    config.ignoreShadowsSingleWindow = true
                    do {
                        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                        guard !Task.isCancelled, self?.generation == session else { return }
                        deliver(window.id, NSImage(cgImage: image, size: NSSize(width: config.width, height: config.height)))
                    } catch { Log.previews.debug("A window preview was unavailable") }
                }
            } catch { Log.previews.debug("Shareable window content unavailable") }
        }
    }

    func end() { generation = UUID(); task?.cancel(); task = nil }
}
