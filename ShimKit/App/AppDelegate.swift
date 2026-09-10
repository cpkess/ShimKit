import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = Preferences.shared
    let permissions = PermissionsManager()
    let shortcuts = ShortcutStore()
    let login = LoginItemManager()
    private let menuBarHider = MenuBarHiderController()
    private let updates = UpdateManager()
    private let discovery = WindowDiscovery()
    private let history = WindowHistory()
    private let manager = WindowManager()
    private let previews = WindowPreviewProvider()
    private lazy var hotkeys = HotkeyManager(shortcuts: shortcuts)
    private lazy var switcher = WindowSwitcherController(discovery: discovery, history: history)
    private lazy var settings = SettingsController(permissions: permissions, shortcuts: shortcuts, hotkeys: hotkeys, login: login, updates: updates, menuBarHider: menuBarHider)
    private var menuBar: MenuBarController?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        menuBar = MenuBarController(shortcuts: shortcuts, openSettings: { [weak self] in self?.showSettings() })
        menuBar?.onCheckForUpdates = { [weak self] in self?.updates.checkForUpdates() }
        menuBar?.canCheckForUpdates = { [weak self] in self?.updates.canCheckForUpdates ?? false }
        menuBar?.onCommand = { [weak self] in self?.manager.perform($0) }
        menuBar?.onSwitch = { [weak self] in
            guard let self else { return }
            self.permissions.refresh()
            if self.permissions.accessibility { self.switcher.advance() } else { self.showSettings() }
        }
        menuBar?.onOpen = { [weak self] in self?.permissions.refresh(); self?.startServices() }
        manager.onFailure = { [weak self] message in
            guard let self else { return }
            if !self.permissions.accessibility { self.showSettings(); return }
            let alert = NSAlert()
            alert.messageText = "This window cannot be positioned"
            alert.informativeText = message
            alert.runModal()
        }
        history.onWindowsChanged = { [weak self] in self?.discovery.refresh() }
        discovery.onChange = { [weak self] windows in
            self?.history.synchronizeWindows(windows)
            self?.manager.prune(liveWindows: windows)
            self?.previews.prepare(windows: self?.history.ordered(windows) ?? windows)
        }
        hotkeys.onCommand = { [weak self] in self?.manager.perform($0) }
        hotkeys.onSwitch = { [weak self] backwards, scope in self?.switcher.advance(backwards: backwards, scope: scope) }
        hotkeys.onCommit = { [weak self] in self?.switcher.commit() }
        hotkeys.onCancel = { [weak self] in self?.switcher.cancel() }
        hotkeys.activeSwitcherScope = { [weak self] in self?.switcher.activeScope }
        switcher.previewsFor = { [weak self] in self?.previews.cachedImages(for: $0) ?? [:] }
        switcher.onPresent = { [weak self] windows in
            self?.previews.begin(windows: windows) { [weak self] key, image in self?.switcher.setPreview(image, for: key) }
        }
        switcher.onDismiss = { [weak self] in self?.previews.end() }
        permissions.onAccessibilityGranted = { [weak self] in self?.startServices() }
        preferences.$showDock.sink { NSApp.setActivationPolicy($0 ? .regular : .accessory) }.store(in: &subscriptions)
        preferences.$showMenuBar.sink { [weak self] in self?.menuBar?.setVisible($0) }.store(in: &subscriptions)
        preferences.$switcherEnabled.sink { [weak self] enabled in if !enabled { self?.switcher.cancel(); self?.previews.clear() } }.store(in: &subscriptions)
        shortcuts.$bindings.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.menuBar?.rebuild() }
        }.store(in: &subscriptions)
        menuBarHider.onSettings = { [weak self] in self?.showSettings() }
        hotkeys.onToggleMenuBar = { [weak self] in self?.menuBarHider.toggle() }
        menuBarHider.start()
        preferences.$previews.dropFirst().sink { [weak self] enabled in
            DispatchQueue.main.async {
                guard let self else { return }
                if enabled { self.previews.prepare(windows: self.history.ordered(self.discovery.windows)) }
                else { self.previews.clear(); self.switcher.cancel() }
            }
        }.store(in: &subscriptions)
        updates.start()
        startServices()
        if !permissions.accessibility { showSettings() }
        Log.app.info("ShimKit started")
    }
    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "ShimKit")
        let settingsItem = appMenu.addItem(withTitle: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        let updateItem = appMenu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdatesAction), keyEquivalent: "")
        updateItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit ShimKit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        NSApp.mainMenu = main
    }
    @objc private func checkForUpdatesAction() { updates.checkForUpdates() }
    @objc private func openSettingsAction() { showSettings() }
    private func startServices() {
        guard permissions.accessibility else { return }
        hotkeys.start()
        history.start()
    }
    func showSettings() { settings.show() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) { hotkeys.stop(); previews.end(); menuBarHider.stop() }
}
