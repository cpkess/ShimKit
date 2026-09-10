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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
