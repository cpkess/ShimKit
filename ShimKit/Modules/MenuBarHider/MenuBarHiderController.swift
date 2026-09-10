import AppKit
import Combine

/// AppKit has no API to hide another application's status item. A wide spacer
/// moves items to its left beyond the screen, while keeping the toggle reachable.
final class MenuBarHiderController: NSObject, ObservableObject {
    enum DisplayState { case expanded, collapsed, arranging }
    @Published private(set) var state: DisplayState = .expanded
    @Published private(set) var message = ""
    private let preferences: Preferences
    private var control: NSStatusItem?
    private var divider: NSStatusItem?
    private var permanentDivider: NSStatusItem?
    private var subscriptions = Set<AnyCancellable>()
    private var timer: Timer?
    private var menu: NSMenu?
    var onSettings: (() -> Void)?

    init(preferences: Preferences = .shared) {
        self.preferences = preferences
        super.init()
    }

    func start() {
        guard subscriptions.isEmpty else { return }
        preferences.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.configure() }
        }.store(in: &subscriptions)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
                                              name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let collapseOnLaunch = preferences.menuBarHiderEnabled && preferences.menuBarHideOnLaunch
        configure()
        if collapseOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.control != nil, self.state == .arranging else { return }
                self.state = .collapsed
                self.apply()
            }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        // Restore space before removing controls, including the always-hidden area.
        divider?.length = 20; permanentDivider?.length = 20
        for item in [permanentDivider, divider, control].compactMap({ $0 }) {
            NSStatusBar.system.removeStatusItem(item)
        }
        permanentDivider = nil; divider = nil; control = nil
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    private func configure() {
        guard preferences.menuBarHiderEnabled else {
            if control != nil {
                // Keep preference observation active while the module is disabled.
                timer?.invalidate(); timer = nil
                for item in [permanentDivider, divider, control].compactMap({ $0 }) {
                    item.length = 20
                    NSStatusBar.system.removeStatusItem(item)
                }
                permanentDivider = nil; divider = nil; control = nil
            }
            state = .expanded; message = ""
            return
        }
        if control == nil {
            control = makeItem(name: "ShimKit.MenuBar.Toggle", divider: false)
            divider = makeItem(name: "ShimKit.MenuBar.Divider", divider: true)
            // First enable stays open so the user can arrange icons safely.
            state = .arranging
        }
        if preferences.menuBarAlwaysHidden && permanentDivider == nil {
            permanentDivider = makeItem(name: "ShimKit.MenuBar.AlwaysHidden", divider: true)
            permanentDivider?.button?.toolTip = "Always-hidden boundary — Command-drag icons to its left"
            state = .arranging
        } else if !preferences.menuBarAlwaysHidden, let item = permanentDivider {
            item.length = 20
            NSStatusBar.system.removeStatusItem(item)
            permanentDivider = nil
        }
        apply()
    }

    private func makeItem(name: String, divider isDivider: Bool) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: isDivider ? 20 : 24)
        item.autosaveName = name
        if let button = item.button {
            button.target = self
            button.action = isDivider ? #selector(showMenu(_:)) : #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            if isDivider {
                let label = DividerLabel(labelWithString: "│")
                label.isEnabled = false
                label.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(label)
                NSLayoutConstraint.activate([label.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -5),
                                             label.centerYAnchor.constraint(equalTo: button.centerYAnchor)])
                button.setAccessibilityLabel("Hidden icons divider")
                button.toolTip = "Command-drag icons to the left to hide them. Click for options."
            }
        }
        return item
    }

    func toggle() {
        guard control != nil else { return }
        state = state == .collapsed ? .expanded : .collapsed
        apply()
    }

    func arrange() {
        guard control != nil else { return }
        state = .arranging
        apply()
    }

    private func apply() {
        timer?.invalidate(); timer = nil
        let hiding = state != .arranging
        if hiding && !validOrder() {
            state = .arranging
            message = "Make the arrow visible and Command-drag both dividers to its left, with the always-hidden divider furthest left. Quit other menu-bar hiding utilities, then try again."
        } else { message = "" }
        let length = Self.collapsedLength(screenWidths: NSScreen.screens.map { $0.frame.width })
        divider?.length = state == .collapsed ? length : 20
        permanentDivider?.length = state == .arranging ? 20 : length
        control?.button?.image = NSImage(systemSymbolName: state == .collapsed ? "chevron.left" : "chevron.right",
                                        accessibilityDescription: state == .collapsed ? "Show hidden menu bar icons" : "Hide menu bar icons")
        control?.button?.toolTip = "\(state == .collapsed ? "Show" : "Hide") menu bar icons. Option-click to arrange all icons; right-click for options."
        scheduleHide()
    }

    private func validOrder() -> Bool {
        guard let arrow = control?.button?.window?.frame,
              let boundary = divider?.button?.window?.frame else { return false }
        guard Self.isReachable(arrow, screens: NSScreen.screens.map(\.frame)),
              Self.isOrdered(left: boundary, right: arrow) else { return false }
        if let permanentDivider {
            guard let frame = permanentDivider.button?.window?.frame,
                  Self.isOrdered(left: frame, right: boundary) else { return false }
        }
        return true
    }

    static func isReachable(_ control: CGRect, screens: [CGRect]) -> Bool {
        screens.contains { screen in
            control.width > 0 && control.minX >= screen.minX && control.maxX <= screen.maxX &&
            control.midY >= screen.minY && control.midY <= screen.maxY
        }
    }

    static func isOrdered(left: CGRect, right: CGRect) -> Bool {
        left.width > 0 && right.width > 0 && abs(left.midY - right.midY) < 2 && left.maxX <= right.minX + 1
    }

    static func collapsedLength(screenWidths: [CGFloat]) -> CGFloat {
        min(10_000, max(500, (screenWidths.filter { $0.isFinite && $0 > 0 }.max() ?? 1_000) * 2))
    }

    private func scheduleHide() {
        timer?.invalidate(); timer = nil
        guard state == .expanded, preferences.menuBarAutoHide else { return }
        let delay = max(2, min(300, preferences.menuBarHideDelay))
        let scheduled = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            let mouse = NSEvent.mouseLocation
            let inMenuBar = NSScreen.screens.contains {
                mouse.x >= $0.frame.minX && mouse.x <= $0.frame.maxX &&
                mouse.y >= $0.frame.maxY - max(24, $0.safeAreaInsets.top) && mouse.y <= $0.frame.maxY
            }
            if inMenuBar || NSEvent.pressedMouseButtons != 0 || self.menu != nil {
                self.scheduleHide()
            } else { self.state = .collapsed; self.apply() }
        }
        timer = scheduled
        // Default mode pauses while AppKit tracks a menu.
        RunLoop.main.add(scheduled, forMode: .default)
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu(sender) }
        else if NSApp.currentEvent?.modifierFlags.contains(.option) == true { arrange() }
        else { toggle() }
    }

    @objc private func showMenu(_ sender: NSStatusBarButton) {
        let options = NSMenu()
        if !message.isEmpty { options.addItem(withTitle: message, action: nil, keyEquivalent: "") }
        for (title, action) in [(state == .collapsed ? "Show Hidden Icons" : "Hide Icons", #selector(toggleAction)),
                                ("Show All Icons to Arrange…", #selector(arrangeAction)),
                                ("ShimKit Settings…", #selector(settingsAction))] {
            let entry = options.addItem(withTitle: title, action: action, keyEquivalent: "")
            entry.target = self
        }
        menu = options
        options.popUp(positioning: nil, at: NSPoint(x: sender.bounds.maxX - 20, y: sender.bounds.minY), in: sender)
        menu = nil
        scheduleHide()
    }
    @objc private func toggleAction() { toggle() }
    @objc private func arrangeAction() { arrange() }
    @objc private func settingsAction() { onSettings?() }
    @objc private func screenChanged() {
        // Reveal first: saved positions can change when a display is disconnected.
        arrange()
    }
}

private final class DividerLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
