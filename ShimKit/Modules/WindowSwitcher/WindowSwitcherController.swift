import AppKit

final class WindowSwitcherController {
    private let discovery: WindowDiscovery
    private let history: WindowHistory
    private let activator = WindowActivator()
    private let panel = SwitcherPanel()
    private var selection = SwitcherSelection()
    private var sessionWindows: [WindowInfo] = []
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private(set) var activeScope: WindowSwitcherScope?
    var isVisible: Bool { activeScope != nil }
    var previewsFor: (([WindowInfo]) -> [WindowKey: NSImage])?
    var onPresent: (([WindowInfo]) -> Void)?
    var onDismiss: (() -> Void)?

    init(discovery: WindowDiscovery, history: WindowHistory) {
        self.discovery = discovery
        self.history = history
        activator.onActivated = { [weak history] in history?.record($0) }
        panel.onChoose = { [weak self] index in
            guard let self else { return }
            self.selection.select(index, count: self.sessionWindows.count)
            self.commit()
        }
    }
    func advance(backwards: Bool = false, scope requestedScope: WindowSwitcherScope? = nil) {
        guard Preferences.shared.switcherEnabled else { return }
        let scope = requestedScope ?? activeScope ?? .allWindows
        if let activeScope, activeScope != scope { cancel() }
        if isVisible {
            selection.advance(count: sessionWindows.count, backwards: backwards)
            panel.updateSelection(selection.index)
            return
        }
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        sessionWindows = history.ordered(scope.windows(from: discovery.windows, frontmostPID: frontmost,
                                                       includeMinimized: Preferences.shared.minimized))
        selection.begin(count: sessionWindows.count, backwards: backwards, currentIsFirst: sessionWindows.first?.pid == frontmost)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        activeScope = scope
        // These monitors exist only for an open session, including invocation from the menu.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.cancel() }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, event.window !== self.panel { self.cancel() }
            return event
        }
        let cached = previewsFor?(sessionWindows) ?? [:]
        panel.present(sessionWindows, selected: selection.index, screen: screen, previewFor: { cached[$0] }, applicationOnly: scope == .currentApplication)
        var previewOrder = sessionWindows
        if previewOrder.indices.contains(selection.index) {
            previewOrder.insert(previewOrder.remove(at: selection.index), at: 0)
        }
        onPresent?(previewOrder)
        discovery.refresh()
    }
    func commit() {
        guard isVisible else { return }
        let window = sessionWindows.indices.contains(selection.index) ? sessionWindows[selection.index] : nil
        cancel()
        if let window {
            DispatchQueue.main.async { [weak self] in self?.activator.activate(window) }
        }
    }
    func cancel() {
        activeScope = nil
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        localClickMonitor = nil
        globalClickMonitor = nil
        panel.clear()
        sessionWindows.removeAll()
        onDismiss?()
    }
    func setPreview(_ image: NSImage, for key: WindowKey) {
        guard isVisible else { return }
        panel.setPreview(image, for: key)
    }
}
