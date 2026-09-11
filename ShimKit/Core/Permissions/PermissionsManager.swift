import AppKit
import ApplicationServices
import Combine

final class PermissionsManager: ObservableObject {
    enum Permission { case accessibility, previews }
    @Published private(set) var accessibility: Bool
    @Published private(set) var screenRecording: Bool
    @Published private(set) var pending: Permission?
    @Published private(set) var message = ""
    var onAccessibilityGranted: (() -> Void)?
    var onAccessibilityRevoked: (() -> Void)?
    var onScreenRecordingChanged: ((Bool) -> Void)?
    private let defaults: UserDefaults
    private let checkAccessibility: () -> Bool
    private let checkScreenRecording: () -> Bool
    private let promptAccessibility: () -> Void
    private let promptScreenRecording: () -> Void
    private let openPane: (String) -> Void
    private var activationToken: NSObjectProtocol?
    private var timer: Timer?
    private var monitorUntil = Date.distantPast
    var isMonitoring: Bool { timer != nil }

    init(defaults: UserDefaults = .standard,
         checkAccessibility: @escaping () -> Bool = { AXIsProcessTrusted() },
         checkScreenRecording: @escaping () -> Bool = { CGPreflightScreenCaptureAccess() },
         promptAccessibility: @escaping () -> Void = {
             let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
             _ = AXIsProcessTrustedWithOptions(options)
         },
         promptScreenRecording: @escaping () -> Void = { _ = CGRequestScreenCaptureAccess() },
         openPane: @escaping (String) -> Void = { pane in
             if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
         }) {
        self.defaults = defaults
        self.checkAccessibility = checkAccessibility
        self.checkScreenRecording = checkScreenRecording
        self.promptAccessibility = promptAccessibility
        self.promptScreenRecording = promptScreenRecording
        self.openPane = openPane
        accessibility = checkAccessibility()
        screenRecording = checkScreenRecording()
        activationToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    deinit {
        timer?.invalidate()
        if let activationToken { NotificationCenter.default.removeObserver(activationToken) }
    }

    func refresh() {
        let trusted = checkAccessibility()
        let capture = checkScreenRecording()
        if accessibility != trusted {
            accessibility = trusted
            if trusted { onAccessibilityGranted?() } else { onAccessibilityRevoked?() }
        }
        if screenRecording != capture { screenRecording = capture; onScreenRecordingChanged?(capture) }
        if pending == .accessibility && trusted || pending == .previews && capture {
            pending = nil
            message = ""
        }
    }

    // Poll only during setup, never indefinitely while the app is idle. Checking
    // on activation also covers a user who spends longer in System Settings.
    func monitorChanges() {
        refresh()
        monitorUntil = Date().addingTimeInterval(120)
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if Date() >= self.monitorUntil { self.stopMonitoring(); return }
            self.refresh()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    func stopMonitoring() { timer?.invalidate(); timer = nil; pending = nil }

    func requestAccessibility() { request(.accessibility) }
    func requestScreenRecording() { request(.previews) }
    private func request(_ permission: Permission) {
        refresh()
        guard permission == .accessibility ? !accessibility : !screenRecording else { return }
        pending = permission
        message = ""
        let key = permission == .accessibility ? "requestedAccessibility" : "requestedScreenRecording"
        if defaults.bool(forKey: key) {
            openPane(permission == .accessibility ? "Privacy_Accessibility" : "Privacy_ScreenCapture")
        } else {
            defaults.set(true, forKey: key)
            // One route per click: the system prompt on the first request;
            // subsequent attempts go directly to the matching Settings pane.
            if permission == .accessibility { promptAccessibility() } else { promptScreenRecording() }
        }
        monitorChanges()
    }

    func revealApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
    func restart() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] app, error in
            DispatchQueue.main.async {
                if let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier, error == nil { NSApp.terminate(nil) }
                else { self?.message = "Could not restart automatically. Quit ShimKit and reopen it from Applications." }
            }
        }
    }
}
