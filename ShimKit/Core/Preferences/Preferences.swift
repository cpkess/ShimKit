import AppKit
import Combine

final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let defaults: UserDefaults
    @Published var showMenuBar: Bool { didSet { defaults.set(showMenuBar, forKey: "showMenuBar") } }
    @Published var showDock: Bool { didSet { defaults.set(showDock, forKey: "showDock") } }
    @Published var managerEnabled: Bool { didSet { defaults.set(managerEnabled, forKey: "managerEnabled") } }
    @Published var switcherEnabled: Bool { didSet { defaults.set(switcherEnabled, forKey: "switcherEnabled") } }
    @Published var previews: Bool { didSet { defaults.set(previews, forKey: "previews") } }
    @Published var minimized: Bool { didSet { defaults.set(minimized, forKey: "minimized") } }
    @Published var appNames: Bool { didSet { defaults.set(appNames, forKey: "appNames") } }
    @Published var windowTitles: Bool { didSet { defaults.set(windowTitles, forKey: "windowTitles") } }

    @Published var menuBarHideOnLaunch: Bool { didSet { defaults.set(menuBarHideOnLaunch, forKey: "menuBarHideOnLaunch") } }
    @Published var menuBarHiderEnabled: Bool { didSet { defaults.set(menuBarHiderEnabled, forKey: "menuBarHiderEnabled") } }
    @Published var menuBarAlwaysHidden: Bool { didSet { defaults.set(menuBarAlwaysHidden, forKey: "menuBarAlwaysHidden") } }
    @Published var menuBarAutoHide: Bool { didSet { defaults.set(menuBarAutoHide, forKey: "menuBarAutoHide") } }
    @Published var menuBarHideDelay: Double { didSet { defaults.set(menuBarHideDelay, forKey: "menuBarHideDelay") } }
    @Published var menuBarHiderHotkey: Bool { didSet { defaults.set(menuBarHiderHotkey, forKey: "menuBarHiderHotkey") } }

    static let portableBooleans: [String: ReferenceWritableKeyPath<Preferences, Bool>] = [
        "showMenuBar": \.showMenuBar,
        "showDock": \.showDock,
        "managerEnabled": \.managerEnabled,
        "switcherEnabled": \.switcherEnabled,
        "previews": \.previews,
        "minimized": \.minimized,
        "appNames": \.appNames,
        "windowTitles": \.windowTitles,
        "menuBarHideOnLaunch": \.menuBarHideOnLaunch,
        "menuBarHiderEnabled": \.menuBarHiderEnabled,
        "menuBarAlwaysHidden": \.menuBarAlwaysHidden,
        "menuBarAutoHide": \.menuBarAutoHide,
        "menuBarHiderHotkey": \.menuBarHiderHotkey,
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["menuBarHideOnLaunch": true])
        menuBarHideOnLaunch = defaults.bool(forKey: "menuBarHideOnLaunch")
        defaults.register(defaults: ["menuBarHiderEnabled": false, "menuBarAlwaysHidden": false, "menuBarAutoHide": true, "menuBarHideDelay": 10, "menuBarHiderHotkey": true])
        menuBarHiderEnabled = defaults.bool(forKey: "menuBarHiderEnabled")
        menuBarAlwaysHidden = defaults.bool(forKey: "menuBarAlwaysHidden")
        menuBarAutoHide = defaults.bool(forKey: "menuBarAutoHide")
        menuBarHideDelay = defaults.double(forKey: "menuBarHideDelay")
        menuBarHiderHotkey = defaults.bool(forKey: "menuBarHiderHotkey")

        defaults.register(defaults: ["showMenuBar": true, "showDock": false,
            "managerEnabled": true, "switcherEnabled": true, "previews": false,
            "minimized": true, "appNames": true, "windowTitles": true])
        showMenuBar = defaults.bool(forKey: "showMenuBar")
        showDock = defaults.bool(forKey: "showDock")
        managerEnabled = defaults.bool(forKey: "managerEnabled")
        switcherEnabled = defaults.bool(forKey: "switcherEnabled")
        previews = defaults.bool(forKey: "previews")
        minimized = defaults.bool(forKey: "minimized")
        appNames = defaults.bool(forKey: "appNames")
        windowTitles = defaults.bool(forKey: "windowTitles")
    }
}
