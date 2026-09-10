import AppKit
import ApplicationServices

struct WindowKey: Hashable {
    let pid: pid_t
    let element: AXUIElement
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.pid == rhs.pid && CFEqual(lhs.element, rhs.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(pid); hasher.combine(CFHash(element)) }
}

struct WindowInfo: Identifiable {
    let id: WindowKey
    let appName: String
    let title: String
    let frame: CGRect
    let minimized: Bool
    var element: AXUIElement { id.element }
    var pid: pid_t { id.pid }
}
