import AppKit
import ApplicationServices

final class WindowManager {
    private var previous: [WindowKey: CGRect] = [:]
    private var cycles: [WindowKey: WindowCycle] = [:]
    var onFailure: ((String) -> Void)?

    func prune(liveWindows: [WindowInfo]) {
        let keys = Set(liveWindows.map(\.id))
        previous = previous.filter { keys.contains($0.key) }
        cycles = cycles.filter { keys.contains($0.key) }
    }

    func perform(_ command: WindowCommand) {
        guard Preferences.shared.managerEnabled else { return }
        guard AXIsProcessTrusted() else { onFailure?("Enable Accessibility in Settings to move windows."); return }
        guard let window = AXAccess.focusedWindow(), let current = AXAccess.frame(window) else { return }
        guard !AXAccess.bool(window, "AXFullScreen") else { onFailure?("Exit full screen before positioning this window."); return }
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else { return }
        let key = WindowKey(pid: pid, element: window)
        guard let primary = NSScreen.screens.first else { return }
        let screens = NSScreen.screens.map { WindowGeometry.accessibilityFrame(fromAppKit: $0.visibleFrame, primaryHeight: primary.frame.height) }
        guard let index = WindowGeometry.displayIndex(for: current, screens: screens) else { return }
        let target: CGRect
        if command == .restore {
            guard let saved = previous[key] else { return }
            // If a display disconnected, keep the restored window reachable.
            if screens.contains(where: { $0.intersects(saved) }) { target = saved }
            else { target = WindowGeometry.frame(for: .center, visible: screens[index], current: saved) }
            cycles[key] = nil
        } else if command == .previousDisplay || command == .nextDisplay {
            let next = (index + (command == .nextDisplay ? 1 : screens.count - 1)) % screens.count
            target = WindowGeometry.moved(current, from: screens[index], to: screens[next])
            cycles[key] = nil
        } else {
            var cycle = cycles[key] ?? WindowCycle()
            let resolved = cycle.resolve(command, current: current)
            target = WindowGeometry.frame(for: resolved, visible: screens[index], current: current)
            cycles[key] = cycle
        }
        let succeeded = AXAccess.setFrame(window, target)
        if let actual = AXAccess.frame(window), !WindowGeometry.approximatelyEqual(current, actual, tolerance: 0.5) {
            previous[key] = current
            cycles[key]?.didApply(actual)
        }
        if !succeeded { Log.windows.debug("Window rejected part of a frame change") }
    }
}
