import AppKit
import ScreenCaptureKit

@MainActor
final class WindowPreviewProvider {
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var warmup: Task<Void, Never>?
    private var cache = PreviewCache<WindowKey, NSImage>(capacity: 24)
    private var visible = false

    func cachedImages(for windows: [WindowInfo]) -> [WindowKey: NSImage] {
        guard Preferences.shared.previews, CGPreflightScreenCaptureAccess() else { return [:] }
        var images: [WindowKey: NSImage] = [:]
        for window in windows { images[window.id] = cache.value(for: window.id) }
        return images
    }

    /// Event-driven preparation; no continuous capture or idle polling.
    func prepare(windows: [WindowInfo]) {
        cache.prune(to: Set(windows.map(\.id)))
        guard Preferences.shared.switcherEnabled, Preferences.shared.previews, CGPreflightScreenCaptureAccess() else { clear(); return }
        guard !visible else { return }
        warmup?.cancel()
        warmup = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self, !self.visible else { return }
            self.capture(windows: windows, deliver: { _, _ in })
        }
    }

    func clear() { end(); cache.removeAll() }

    func begin(windows: [WindowInfo], deliver: @escaping (WindowKey, NSImage) -> Void) {
        end()
        visible = true
        capture(windows: windows, deliver: deliver)
    }

    private func capture(windows: [WindowInfo], deliver: @escaping (WindowKey, NSImage) -> Void) {
        generation = UUID()
        task?.cancel()
        guard Preferences.shared.previews, CGPreflightScreenCaptureAccess() else { return }
        for window in windows {
            if let image = cache.value(for: window.id) { deliver(window.id, image) }
        }
        let candidatesToRefresh = Array(windows.prefix(24)).filter {
            !$0.minimized && !cache.isFresh($0.id, maxAge: 3)
        }
        guard !candidatesToRefresh.isEmpty else { return }
        let session = generation
        task = Task { [weak self] in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
                // AX has no public window-ID accessor. Match conservatively; ambiguous windows keep their icons.
                for window in candidatesToRefresh {
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
                        let preview = NSImage(cgImage: image, size: NSSize(width: config.width, height: config.height))
                        self?.cache.insert(preview, for: window.id)
                        deliver(window.id, preview)
                    } catch { Log.previews.debug("A window preview was unavailable") }
                }
            } catch { Log.previews.debug("Shareable window content unavailable") }
        }
    }

    func end() { visible = false; warmup?.cancel(); warmup = nil; generation = UUID(); task?.cancel(); task = nil }
}

/// Bounded memory-only snapshots survive dismissal and are pruned when windows close.
struct PreviewCache<Key: Hashable, Value> {
    private struct Entry { let value: Value; let date: Date }
    let capacity: Int
    private var entries: [Key: Entry] = [:]
    init(capacity: Int) { self.capacity = capacity }
    func value(for key: Key) -> Value? { entries[key]?.value }
    func isFresh(_ key: Key, maxAge: TimeInterval, now: Date = Date()) -> Bool {
        guard let entry = entries[key] else { return false }
        return now.timeIntervalSince(entry.date) < maxAge
    }
    mutating func insert(_ value: Value, for key: Key, now: Date = Date()) {
        guard capacity > 0 else { return }
        entries[key] = Entry(value: value, date: now)
        while entries.count > capacity, let oldest = entries.min(by: { $0.value.date < $1.value.date })?.key {
            entries.removeValue(forKey: oldest)
        }
    }
    mutating func prune(to keys: Set<Key>) { entries = entries.filter { keys.contains($0.key) } }
    mutating func removeAll() { entries.removeAll() }
}
