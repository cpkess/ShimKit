import AppKit
import ApplicationServices

struct MRUList<Key: Hashable> {
    private(set) var keys: [Key] = []
    mutating func record(_ key: Key) { keys.removeAll { $0 == key }; keys.insert(key, at: 0) }
    mutating func prune(to live: Set<Key>) { keys.removeAll { !live.contains($0) } }
    func ordered(_ available: [Key]) -> [Key] {
        let live = Set(available)
        let recent = keys.filter { live.contains($0) }
        let seen = Set(recent)
        return recent + available.filter { !seen.contains($0) }
    }
}

final class WindowHistory {
    private struct Observation {
        let observer: AXObserver
        let application: AXUIElement
        var windows: Set<WindowKey> = []
    }
    private var observations: [pid_t: Observation] = [:]
    private var tokens: [NSObjectProtocol] = []
    private var pending: DispatchWorkItem?
    private(set) var mru = MRUList<WindowKey>()
    var onWindowsChanged: (() -> Void)?

    func start() {
        guard tokens.isEmpty, AXIsProcessTrusted() else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification, NSWorkspace.didHideApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.synchronizeApplications()
                self?.recordFocusedWindow()
                self?.scheduleRefresh()
            })
        }
        synchronizeApplications()
        recordFocusedWindow()
        onWindowsChanged?()
    }

    deinit {
        pending?.cancel()
        for token in tokens { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        for entry in observations.values {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(entry.observer), .commonModes)
        }
    }

    private func synchronizeApplications() {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        let live = Set(apps.map(\.processIdentifier))
        for pid in Array(observations.keys) where !live.contains(pid) {
            if let entry = observations.removeValue(forKey: pid) {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(entry.observer), .commonModes)
            }
        }
        for app in apps where observations[app.processIdentifier] == nil {
            var observer: AXObserver?
            guard AXObserverCreate(app.processIdentifier, { _, _, notification, context in
                guard let context else { return }
                let history = Unmanaged<WindowHistory>.fromOpaque(context).takeUnretainedValue()
                let name = notification as String
                if name == kAXFocusedWindowChangedNotification || name == kAXMainWindowChangedNotification {
                    history.recordFocusedWindow()
                }
                history.scheduleRefresh()
            }, &observer) == .success, let observer else { continue }
            let element = AXAccess.application(app.processIdentifier)
            observations[app.processIdentifier] = Observation(observer: observer, application: element)
            for name in [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification, kAXWindowCreatedNotification] {
                AXObserverAddNotification(observer, element, name as CFString, Unmanaged.passUnretained(self).toOpaque())
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }

    func synchronizeWindows(_ windows: [WindowInfo]) {
        mru.prune(to: Set(windows.map(\.id)))
        for pid in Array(observations.keys) {
            guard var entry = observations[pid] else { continue }
            let live = Set(windows.filter { $0.pid == pid }.map(\.id))
            let names = [kAXUIElementDestroyedNotification, kAXWindowMiniaturizedNotification,
                         kAXWindowDeminiaturizedNotification, kAXTitleChangedNotification,
                         kAXMovedNotification, kAXResizedNotification]
            for removed in entry.windows.subtracting(live) {
                for name in names { AXObserverRemoveNotification(entry.observer, removed.element, name as CFString) }
            }
            for added in live.subtracting(entry.windows) {
                for name in names {
                    AXObserverAddNotification(entry.observer, added.element, name as CFString, Unmanaged.passUnretained(self).toOpaque())
                }
            }
            entry.windows = live
            observations[pid] = entry
        }
        recordFocusedWindow()
    }

    func record(_ key: WindowKey) { mru.record(key) }
    private func recordFocusedWindow() {
        guard let window = AXAccess.focusedWindow() else { return }
        var pid: pid_t = 0
        if AXUIElementGetPid(window, &pid) == .success { mru.record(WindowKey(pid: pid, element: window)) }
    }
    private func scheduleRefresh() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onWindowsChanged?() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }
    func ordered(_ windows: [WindowInfo]) -> [WindowInfo] {
        let lookup = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return mru.ordered(windows.map(\.id)).compactMap { lookup[$0] }
    }
}
