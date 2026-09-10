import AppKit
import ApplicationServices

/// Calls that may involve another process run on a serial queue, never on the key-event path.
final class WindowDiscovery {
    private let queue = DispatchQueue(label: "com.shimkit.discovery", qos: .userInitiated)
    private var busy = false
    private var needsRefresh = false
    private(set) var windows: [WindowInfo] = []
    var onChange: (([WindowInfo]) -> Void)?

    func refresh() {
        guard AXIsProcessTrusted() else { return }
        guard !busy else { needsRefresh = true; return }
        busy = true
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated
        }.map { ($0.processIdentifier, $0.localizedName ?? "Application") }
        queue.async { [weak self] in
            var result: [WindowInfo] = []
            for (pid, name) in apps {
                let app = AXAccess.application(pid)
                guard let elements = AXAccess.value(app, kAXWindowsAttribute) as? [AXUIElement] else { continue }
                for element in elements {
                    AXUIElementSetMessagingTimeout(element, 0.15)
                    guard AXAccess.string(element, kAXRoleAttribute) == kAXWindowRole,
                          AXAccess.string(element, kAXSubroleAttribute) == kAXStandardWindowSubrole,
                          !AXAccess.bool(element, kAXHiddenAttribute),
                          let frame = AXAccess.frame(element), frame.width > 1, frame.height > 1 else { continue }
                    let minimized = AXAccess.bool(element, kAXMinimizedAttribute)
                    result.append(WindowInfo(id: WindowKey(pid: pid, element: element), appName: name,
                        title: AXAccess.string(element, kAXTitleAttribute), frame: frame, minimized: minimized))
                }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.windows = result
                self.busy = false
                self.onChange?(result)
                if self.needsRefresh { self.needsRefresh = false; self.refresh() }
            }
        }
    }
}
