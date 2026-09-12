import Foundation

/// Only user-facing preferences; never permissions, account data, or window contents.
struct PreferencesArchive: Codable {
    var format = "com.shimkit.preferences"
    var version = 1
    var settings: [String: Bool]
    var menuBarHideDelay: Double
    var shortcuts: [String: Shortcut]
    var launchAtLogin: Bool
    var automaticUpdateChecks: Bool
    var automaticUpdateDownloads: Bool

    enum ArchiveError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            if case let .invalid(reason) = self { return reason }
            return nil
        }
    }

    func validatedBindings() throws -> [WindowCommand: Shortcut] {
        guard format == "com.shimkit.preferences", version == 1 else {
            throw ArchiveError.invalid("Unsupported preferences format. Update ShimKit and try again.")
        }
        guard Set(settings.keys) == Set(Preferences.portableBooleans.keys),
              [5.0, 10, 30, 60].contains(menuBarHideDelay) else {
            throw ArchiveError.invalid("This file has missing or invalid settings.")
        }
        var result: [WindowCommand: Shortcut] = [:]
        for (name, shortcut) in shortcuts {
            guard let command = WindowCommand(rawValue: name),
                  (1...4).contains(shortcut.keyCodes.count),
                  shortcut.modifiers & ~Shortcut.relevantFlags.rawValue == 0,
                  shortcut.flags.contains(.maskControl) || shortcut.flags.contains(.maskAlternate) || shortcut.flags.contains(.maskCommand),
                  shortcut.keyCodes.allSatisfy({ code in Shortcut.keys.contains { $0.code == code } }),
                  !shortcut.keyCodes.contains(where: { WindowSwitcherScope.matching(keyCode: $0, flags: shortcut.flags) != nil }),
                  !result.values.contains(shortcut) else {
                throw ArchiveError.invalid("Invalid, reserved, or duplicate shortcut: \(name).")
            }
            result[command] = shortcut
        }
        return result
    }

    static func decode(_ data: Data) throws -> PreferencesArchive {
        guard data.count <= 1_048_576 else { throw ArchiveError.invalid("The preferences file is too large.") }
        let archive = try JSONDecoder().decode(Self.self, from: data)
        _ = try archive.validatedBindings()
        return archive
    }

    func encoded() throws -> Data {
        _ = try validatedBindings()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    func apply(to preferences: Preferences, shortcuts store: ShortcutStore) throws {
        let bindings = try validatedBindings()
        for (key, path) in Preferences.portableBooleans { preferences[keyPath: path] = settings[key]! }
        preferences.menuBarHideDelay = menuBarHideDelay
        store.replace(with: bindings)
    }
}
