import XCTest
import AppKit
@testable import ShimKit

final class MenuBarHiderTests: XCTestCase {
    func testNativeOverflowKeepsEveryItemBelowWidthAndNotchLimits() {
        let lengths = MenuBarHiderController.nativeOverflowLengths(screenWidths: [1728, 3840], trailingWidths: [771.5])
        XCTAssertEqual(lengths.count, 7)
        XCTAssertTrue(lengths.allSatisfy { $0 == 707 })
        XCTAssertGreaterThan(lengths.reduce(0, +), 3840)
        let normal = MenuBarHiderController.nativeOverflowLengths(screenWidths: [1440], trailingWidths: [])
        XCTAssertGreaterThanOrEqual(normal.reduce(0, +), 2880)
        XCTAssertTrue(normal.allSatisfy { $0 < 720 })
        for widths: [CGFloat] in [[], [0, -1, .nan], [100]] {
            let result = MenuBarHiderController.nativeOverflowLengths(screenWidths: widths, trailingWidths: [.nan])
            XCTAssertTrue((1...7).contains(result.count))
            XCTAssertTrue(result.allSatisfy { $0.isFinite && $0 > 0 })
        }
    }

    func testSpacerUsesWidestDisplayAndCapsExtremeSizes() {
        XCTAssertEqual(MenuBarHiderController.collapsedLength(screenWidths: [1440, 2560]), 5120)
        XCTAssertEqual(MenuBarHiderController.collapsedLength(screenWidths: [8000]), 10000)
        XCTAssertEqual(MenuBarHiderController.collapsedLength(screenWidths: [0, -1, .nan]), 2000)
        XCTAssertEqual(MenuBarHiderController.collapsedLength(screenWidths: [100]), 500)
    }

    func testMisplacedDividerCannotHideToggle() {
        let arrow = CGRect(x: 500, y: 1000, width: 24, height: 24)
        XCTAssertTrue(MenuBarHiderController.isOrdered(left: CGRect(x: 480, y: 1000, width: 20, height: 24), right: arrow))
        XCTAssertTrue(MenuBarHiderController.isOrdered(left: CGRect(x: -3500, y: 1000, width: 4000, height: 24), right: arrow))
        XCTAssertFalse(MenuBarHiderController.isOrdered(left: CGRect(x: 524, y: 1000, width: 20, height: 24), right: arrow))
        XCTAssertFalse(MenuBarHiderController.isOrdered(left: CGRect(x: 480, y: 500, width: 20, height: 24), right: arrow))
        XCTAssertFalse(MenuBarHiderController.isOrdered(left: .zero, right: arrow))
    }

    func testOffscreenTogglePreventsCollapsing() {
        let screens = [CGRect(x: -1440, y: 0, width: 1440, height: 900),
                       CGRect(x: 0, y: 0, width: 1728, height: 1117)]
        XCTAssertTrue(MenuBarHiderController.isReachable(CGRect(x: -200, y: 876, width: 24, height: 24), screens: screens))
        XCTAssertFalse(MenuBarHiderController.isReachable(CGRect(x: -3959, y: 1080, width: 40, height: 37), screens: screens))
        XCTAssertFalse(MenuBarHiderController.isReachable(CGRect(x: 1720, y: 1093, width: 24, height: 24), screens: screens))
    }

    func testMenuBarDefaultsAndSettingsPersistIndependently() {
        let name = "ShimKitTests.MenuBar.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = Preferences(defaults: defaults)
        XCTAssertTrue(preferences.menuBarHiderEnabled)
        XCTAssertFalse(preferences.menuBarAlwaysHidden)
        XCTAssertTrue(preferences.menuBarAutoHide)
        preferences.menuBarHiderEnabled = false
        preferences.menuBarAlwaysHidden = true
        preferences.menuBarHideDelay = 30
        let restored = Preferences(defaults: defaults)
        XCTAssertFalse(restored.menuBarHiderEnabled)
        XCTAssertTrue(restored.menuBarAlwaysHidden)
        XCTAssertEqual(restored.menuBarHideDelay, 30)
        XCTAssertTrue(restored.switcherEnabled)
        XCTAssertFalse(Shortcut.defaults.values.contains(Shortcut.menuBarHider))
        XCTAssertFalse(Shortcut.menuBarHider.matches(code: 48, flags: .maskAlternate))
    }
}
