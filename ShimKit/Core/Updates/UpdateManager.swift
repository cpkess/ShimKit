import AppKit
import Combine
import Sparkle

/// Sparkle owns scheduling, signature verification, atomic installation, and relaunch.
/// Window discovery and window contents are never supplied to the updater.
@MainActor
final class UpdateManager: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecks = false
    @Published private(set) var automaticallyDownloads = false
    @Published private(set) var lastCheck: Date?
    private let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    private var started = false

    init() {
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticallyChecks)
        controller.updater.publisher(for: \.automaticallyDownloadsUpdates).assign(to: &$automaticallyDownloads)
        controller.updater.publisher(for: \.lastUpdateCheckDate).assign(to: &$lastCheck)
    }

    func start() {
        guard !started, Bundle.main.bundleURL.pathExtension == "app" else { return }
        started = true
        controller.startUpdater()
        // Override any old preference as well as disabling profiling in Info.plist.
        controller.updater.sendsSystemProfile = false
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        controller.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func setAutomaticDownloads(_ enabled: Bool) {
        controller.updater.automaticallyDownloadsUpdates = enabled
    }
}
