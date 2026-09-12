import Foundation

/// Generated from Resources/DefaultPreferences.json by scripts/generate-defaults.py.
enum FactoryDefaults {
    static let settings: [String: Any] = [
        "appNames": true,
        "managerEnabled": true,
        "menuBarAlwaysHidden": false,
        "menuBarAutoHide": true,
        "menuBarHideOnLaunch": true,
        "menuBarHiderEnabled": true,
        "menuBarHiderHotkey": true,
        "minimized": true,
        "previews": true,
        "showDock": false,
        "showMenuBar": true,
        "switcherEnabled": true,
        "windowTitles": true,
        "menuBarHideDelay": 10.0,
    ]
    static let launchAtLogin = true
    static let shortcuts: [WindowCommand: Shortcut] = [
        .bottomLeft: Shortcut(keyCodes: [38], modifiers: 786432),
        .bottomRight: Shortcut(keyCodes: [40], modifiers: 786432),
        .center: Shortcut(keyCodes: [8], modifiers: 786432),
        .centerThird: Shortcut(keyCodes: [126], modifiers: 1835008),
        .left: Shortcut(keyCodes: [123], modifiers: 786432),
        .leftThird: Shortcut(keyCodes: [123], modifiers: 1835008),
        .leftTwoThirds: Shortcut(keyCodes: [123, 126], modifiers: 1835008),
        .maximize: Shortcut(keyCodes: [126], modifiers: 786432),
        .restore: Shortcut(keyCodes: [125], modifiers: 786432),
        .right: Shortcut(keyCodes: [124], modifiers: 786432),
        .rightThird: Shortcut(keyCodes: [124], modifiers: 1835008),
        .rightTwoThirds: Shortcut(keyCodes: [124, 126], modifiers: 1835008),
        .topLeft: Shortcut(keyCodes: [32], modifiers: 786432),
        .topRight: Shortcut(keyCodes: [34], modifiers: 786432),
    ]
}
