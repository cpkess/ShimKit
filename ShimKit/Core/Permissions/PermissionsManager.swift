import AppKit
import ApplicationServices
import Combine

final class PermissionsManager: ObservableObject {
    @Published private(set) var accessibility = AXIsProcessTrusted()
    @Published private(set) var screenRecording = CGPreflightScreenCaptureAccess()
    var onAccessibilityGranted: (() -> Void)?
    private var activationToken: NSObjectProtocol?

    init() {
        activationToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    deinit { if let activationToken { NotificationCenter.default.removeObserver(activationToken) } }

    func refresh() {
        let wasTrusted = accessibility
        accessibility = AXIsProcessTrusted()
        screenRecording = CGPreflightScreenCaptureAccess()
        if accessibility && !wasTrusted { onAccessibilityGranted?() }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacy("Privacy_Accessibility")
    }

    func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        refresh()
        openPrivacy("Privacy_ScreenCapture")
    }

    func openPrivacy(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}
