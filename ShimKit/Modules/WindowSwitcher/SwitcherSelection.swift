import AppKit

struct SwitcherSelection {
    private(set) var index = 0
    mutating func begin(count: Int, backwards: Bool, currentIsFirst: Bool = true) {
        guard count > 0 else { index = 0; return }
        index = backwards ? count - 1 : (currentIsFirst ? min(1, count - 1) : 0)
    }
    mutating func advance(count: Int, backwards: Bool) {
        guard count > 0 else { index = 0; return }
        index = (index + (backwards ? count - 1 : 1)) % count
    }
    mutating func select(_ index: Int, count: Int) { self.index = max(0, min(index, max(0, count - 1))) }
}

/// The scope and release modifier stay fixed for the duration of a switching session.
enum WindowSwitcherScope: CaseIterable {
    case allWindows
    case currentApplication

    var shortcut: Shortcut {
        switch self {
        case .allWindows: return .switcher
        case .currentApplication: return .applicationSwitcher
        }
    }

    static func matching(keyCode: UInt16, flags: CGEventFlags) -> Self? {
        allCases.first { $0.shortcut.matches(code: keyCode, flags: flags.subtracting(.maskShift)) }
    }

    func shouldCommit(flags: CGEventFlags) -> Bool {
        flags.intersection(shortcut.flags) != shortcut.flags
    }

    func windows(from windows: [WindowInfo], frontmostPID: pid_t?, includeMinimized: Bool) -> [WindowInfo] {
        windows.filter { window in
            (includeMinimized || !window.minimized) &&
            (self == .allWindows || window.pid == frontmostPID)
        }
    }
}
