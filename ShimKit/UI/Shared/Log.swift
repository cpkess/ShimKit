import OSLog

enum Log {
    static let app = Logger(subsystem: "com.shimkit.app", category: "app")
    static let accessibility = Logger(subsystem: "com.shimkit.app", category: "accessibility")
    static let hotkeys = Logger(subsystem: "com.shimkit.app", category: "hotkeys")
    static let windows = Logger(subsystem: "com.shimkit.app", category: "windows")
    static let switcher = Logger(subsystem: "com.shimkit.app", category: "switcher")
    static let previews = Logger(subsystem: "com.shimkit.app", category: "previews")
    static let permissions = Logger(subsystem: "com.shimkit.app", category: "permissions")
}
