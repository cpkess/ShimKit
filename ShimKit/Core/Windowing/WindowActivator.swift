import AppKit
import ApplicationServices

final class WindowActivator {
    private var retry: DispatchWorkItem?
    var onActivated: ((WindowKey) -> Void)?

    func activate(_ window: WindowInfo) {
        retry?.cancel()
        guard let app = NSRunningApplication(processIdentifier: window.pid), !app.isTerminated,
              AXAccess.frame(window.element) != nil else { return }
        if AXAccess.bool(window.element, kAXMinimizedAttribute) {
            _ = AXAccess.set(window.element, kAXMinimizedAttribute, kCFBooleanFalse)
        }
        app.unhide()
        app.activate(options: [])
        focus(window)
        // Some apps finish unminimizing asynchronously. One bounded retry, never a polling loop.
        let work = DispatchWorkItem { [weak self] in
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == window.pid else { return }
            self?.focus(window)
        }
        retry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func focus(_ window: WindowInfo) {
        guard AXAccess.frame(window.element) != nil else { return }
        let app = AXAccess.application(window.pid)
        _ = AXAccess.set(window.element, kAXMainAttribute, kCFBooleanTrue)
        _ = AXAccess.set(app, kAXFocusedWindowAttribute, window.element)
        let result = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        _ = AXAccess.set(window.element, kAXFocusedAttribute, kCFBooleanTrue)
        if result == .success { onActivated?(window.id) }
        else { Log.windows.debug("Window activation was not accepted by its owner") }
    }
}
