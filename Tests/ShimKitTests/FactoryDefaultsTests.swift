import XCTest
@testable import ShimKit

final class FactoryDefaultsTests: XCTestCase {
    func testFreshPreferencesExactlyMatchApprovedArchive() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let archive = try PreferencesArchive.decode(Data(contentsOf: root.appendingPathComponent("Resources/DefaultPreferences.json")))
        let name = "ShimKitTests.factory.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = Preferences(defaults: defaults)
        for (key, path) in Preferences.portableBooleans {
            XCTAssertEqual(preferences[keyPath: path], archive.settings[key], key)
        }
        XCTAssertEqual(preferences.menuBarHideDelay, archive.menuBarHideDelay)
        XCTAssertEqual(ShortcutStore(defaults: defaults).bindings, try archive.validatedBindings())
        XCTAssertEqual(FactoryDefaults.launchAtLogin, archive.launchAtLogin)
        let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: root.appendingPathComponent("Resources/Info.plist")), format: nil) as! [String: Any]
        XCTAssertEqual(info["SUEnableAutomaticChecks"] as? Bool, archive.automaticUpdateChecks)
        XCTAssertEqual(info["SUAutomaticallyUpdate"] as? Bool, archive.automaticUpdateDownloads)
    }
    func testSavedChoicesAndRemovedShortcutsSurviveNewDefaults() throws {
        let name = "ShimKitTests.factory.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(false, forKey: "previews")
        defaults.set(false, forKey: "menuBarHiderEnabled")
        defaults.set(60.0, forKey: "menuBarHideDelay")
        defaults.set(try JSONEncoder().encode([WindowCommand: Shortcut]()), forKey: "shortcuts")
        let preferences = Preferences(defaults: defaults)
        XCTAssertFalse(preferences.previews)
        XCTAssertFalse(preferences.menuBarHiderEnabled)
        XCTAssertEqual(preferences.menuBarHideDelay, 60)
        let store = ShortcutStore(defaults: defaults)
        XCTAssertTrue(store.bindings.isEmpty)
        store.reset()
        XCTAssertEqual(store.bindings, FactoryDefaults.shortcuts)
    }
}
