import XCTest
@testable import ShimKit

final class PreferencesArchiveTests: XCTestCase {
    private func archive() -> PreferencesArchive {
        PreferencesArchive(settings: Preferences.portableBooleans.mapValues { _ in true }, menuBarHideDelay: 30,
                           shortcuts: Dictionary(uniqueKeysWithValues: Shortcut.defaults.map { ($0.key.rawValue, $0.value) }),
                           launchAtLogin: true, automaticUpdateChecks: false, automaticUpdateDownloads: false)
    }
    func testRoundTripAndPersistenceIncludesRemovedShortcutsAndChords() throws {
        let name = "ShimKitTests.archive.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = Preferences(defaults: defaults)
        let store = ShortcutStore(defaults: defaults)
        var original = archive()
        let chord = Shortcut(keyCodes: [123, 126], modifiers: Shortcut.relevantFlags.rawValue)
        original.shortcuts = [WindowCommand.left.rawValue: chord]
        let restored = try PreferencesArchive.decode(original.encoded())
        try restored.apply(to: preferences, shortcuts: store)
        let reloaded = Preferences(defaults: defaults)
        for path in Preferences.portableBooleans.values { XCTAssertTrue(reloaded[keyPath: path]) }
        XCTAssertEqual(reloaded.menuBarHideDelay, 30)
        XCTAssertEqual(ShortcutStore(defaults: defaults).bindings, [.left: chord])
        XCTAssertTrue(restored.launchAtLogin)
        XCTAssertFalse(restored.automaticUpdateChecks)
        XCTAssertFalse(restored.automaticUpdateDownloads)
    }
    func testInvalidImportLeavesPreferencesUntouched() throws {
        let name = "ShimKitTests.archive.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = Preferences(defaults: defaults)
        let store = ShortcutStore(defaults: defaults)
        let before = store.bindings
        var invalid = archive()
        invalid.shortcuts = ["unknownCommand": Shortcut.defaults[.left]!]
        XCTAssertThrowsError(try invalid.apply(to: preferences, shortcuts: store))
        XCTAssertFalse(preferences.showDock)
        XCTAssertEqual(store.bindings, before)
    }
    func testRejectsInvalidSettingsAndFutureFormats() throws {
        var value = archive()
        value.version = 2
        XCTAssertThrowsError(try value.encoded())
        value = archive(); value.settings.removeValue(forKey: "previews")
        XCTAssertThrowsError(try value.encoded())
        value = archive(); value.menuBarHideDelay = -1
        XCTAssertThrowsError(try value.encoded())
        XCTAssertThrowsError(try PreferencesArchive.decode(Data("{}".utf8)))
        XCTAssertThrowsError(try PreferencesArchive.decode(Data(repeating: 0, count: 1_048_577)))
    }
    func testShortcutValidationAllowsAmbiguousChordsButRejectsDuplicatesAndReservedKeys() throws {
        var value = archive()
        let single = Shortcut.defaults[.left]!
        value.shortcuts = ["left": single, "right": Shortcut(keyCodes: [123, 126], modifiers: single.modifiers)]
        XCTAssertNoThrow(try value.encoded())
        value.shortcuts["right"] = single
        XCTAssertThrowsError(try value.encoded())
        value.shortcuts = ["left": .switcher]
        XCTAssertThrowsError(try value.encoded())
        value.shortcuts = ["left": Shortcut(keyCode: 123, modifiers: 0)]
        XCTAssertThrowsError(try value.encoded())
        value.shortcuts = [:]
        XCTAssertNoThrow(try value.encoded())
    }
}
