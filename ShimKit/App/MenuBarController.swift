import AppKit

final class MenuBarController: NSObject, NSMenuDelegate, NSMenuItemValidation {
    private var item: NSStatusItem?
    private let openSettings: () -> Void
    private let shortcuts: ShortcutStore
    var onCommand: ((WindowCommand) -> Void)?
    var onSwitch: (() -> Void)?
    var onCheckForUpdates: (() -> Void)?
    var canCheckForUpdates: (() -> Bool)?
    var onOpen: (() -> Void)?

    init(shortcuts: ShortcutStore, openSettings: @escaping () -> Void) {
        self.shortcuts = shortcuts
        self.openSettings = openSettings
        super.init()
    }
    func setVisible(_ visible: Bool) {
        if !visible {
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil
            return
        }
        guard item == nil else { return }
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "ShimKit")
        item = status
        rebuild()
    }
    func rebuild() {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "ShimKit", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let window = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let commands = NSMenu()
        commands.autoenablesItems = false
        for command in WindowCommand.allCases {
            if [.topLeft, .leftThird, .maximize, .previousDisplay].contains(command) { commands.addItem(.separator()) }
            let binding = shortcuts.bindings[command]
            let ambiguous = binding.map { shortcut in
                shortcuts.bindings.values.contains { $0.modifiers == shortcut.modifiers &&
                    $0.keyCodes.count > shortcut.keyCodes.count && Set(shortcut.keyCodes).isSubset(of: Set($0.keyCodes)) }
            } ?? false
            let displayOnly = (binding?.keyCodes.count ?? 0) > 1 || ambiguous
            let title = command.title + (displayOnly ? "    \(binding!.label)" : "")
            let entry = NSMenuItem(title: title, action: #selector(windowAction(_:)), keyEquivalent: displayOnly ? "" : (binding?.keyEquivalent ?? ""))
            entry.keyEquivalentModifierMask = shortcuts.bindings[command]?.eventModifiers ?? []
            entry.representedObject = command.rawValue
            entry.target = self
            entry.isEnabled = Preferences.shared.managerEnabled
            commands.addItem(entry)
        }
        window.submenu = commands
        menu.addItem(window)
        let switcher = menu.addItem(withTitle: "Window Switcher", action: #selector(switchAction), keyEquivalent: "\t")
        switcher.keyEquivalentModifierMask = .option
        switcher.target = self
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "Settings…", action: #selector(settingsAction), keyEquivalent: ",")
        settings.target = self
        let updateItem = menu.addItem(withTitle: "Check for Updates…", action: #selector(updateAction), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(withTitle: "Quit ShimKit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item?.menu = menu
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(updateAction) { return canCheckForUpdates?() ?? false }
        return true
    }
    func menuWillOpen(_ menu: NSMenu) {
        onOpen?()
        if let submenu = menu.items.first(where: { $0.title == "Window" })?.submenu {
            for item in submenu.items where !item.isSeparatorItem { item.isEnabled = Preferences.shared.managerEnabled }
        }
    }
    @objc private func windowAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let command = WindowCommand(rawValue: raw) else { return }
        onCommand?(command)
    }
    @objc private func updateAction() { onCheckForUpdates?() }
    @objc private func settingsAction() { openSettings() }
    @objc private func switchAction() { onSwitch?() }
}
