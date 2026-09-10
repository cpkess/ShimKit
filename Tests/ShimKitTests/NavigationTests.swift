import XCTest
import ApplicationServices
@testable import ShimKit

final class NavigationTests: XCTestCase {
    func testApplicationShortcutAndReverseAreDistinctFromAllWindows() {
        XCTAssertEqual(WindowSwitcherScope.matching(keyCode: 50, flags: .maskCommand), .currentApplication)
        XCTAssertEqual(WindowSwitcherScope.matching(keyCode: 50, flags: [.maskCommand, .maskShift, .maskAlphaShift]), .currentApplication)
        XCTAssertEqual(WindowSwitcherScope.matching(keyCode: 48, flags: [.maskAlternate, .maskShift]), .allWindows)
        XCTAssertNil(WindowSwitcherScope.matching(keyCode: 50, flags: .maskAlternate))
        XCTAssertNil(WindowSwitcherScope.matching(keyCode: 50, flags: [.maskCommand, .maskControl]))
        XCTAssertEqual(Shortcut.applicationSwitcher.label, "⌘`")
    }

    func testEachScopeCommitsOnlyWhenItsOwnModifierIsReleased() {
        XCTAssertFalse(WindowSwitcherScope.currentApplication.shouldCommit(flags: [.maskCommand, .maskShift]))
        XCTAssertFalse(WindowSwitcherScope.currentApplication.shouldCommit(flags: .maskCommand))
        XCTAssertTrue(WindowSwitcherScope.currentApplication.shouldCommit(flags: .maskShift))
        XCTAssertTrue(WindowSwitcherScope.currentApplication.shouldCommit(flags: .maskAlternate))
        XCTAssertFalse(WindowSwitcherScope.allWindows.shouldCommit(flags: .maskAlternate))
        XCTAssertTrue(WindowSwitcherScope.allWindows.shouldCommit(flags: .maskCommand))
    }

    func testAppScopeKeepsOnlyFrontmostAppWindowsInSnapshotOrder() {
        func window(_ pid: pid_t, _ title: String, minimized: Bool = false) -> WindowInfo {
            WindowInfo(id: WindowKey(pid: pid, element: AXUIElementCreateApplication(pid)),
                       appName: "Application", title: title,
                       frame: CGRect(x: 0, y: 0, width: 800, height: 600), minimized: minimized)
        }
        let windows = [window(10, "Current"), window(20, "Other app"),
                       window(10, "Second"), window(10, "Minimized", minimized: true)]
        let scope = WindowSwitcherScope.currentApplication
        XCTAssertEqual(scope.windows(from: windows, frontmostPID: 10, includeMinimized: true).map(\.title),
                       ["Current", "Second", "Minimized"])
        XCTAssertEqual(scope.windows(from: windows, frontmostPID: 10, includeMinimized: false).map(\.title),
                       ["Current", "Second"])
        XCTAssertTrue(scope.windows(from: windows, frontmostPID: nil, includeMinimized: true).isEmpty)
        XCTAssertTrue(scope.windows(from: windows, frontmostPID: 30, includeMinimized: true).isEmpty)
        XCTAssertEqual(WindowSwitcherScope.allWindows.windows(from: windows, frontmostPID: 10,
                                                              includeMinimized: true).count, 4)
    }

    func testMRUOrderingDeduplicationAndPruning() {
        var history = MRUList<Int>()
        history.record(2)
        history.record(1)
        history.record(2)
        XCTAssertEqual(history.ordered([1, 2, 3]), [2, 1, 3])
        history.prune(to: [1, 3])
        XCTAssertEqual(history.ordered([1, 3]), [1, 3])
    }
    func testSwitcherForwardBackwardAndWrap() {
        var selection = SwitcherSelection()
        selection.begin(count: 5, backwards: false)
        XCTAssertEqual(selection.index, 1)
        selection.advance(count: 5, backwards: true)
        XCTAssertEqual(selection.index, 0)
        selection.advance(count: 5, backwards: true)
        XCTAssertEqual(selection.index, 4)
        selection.advance(count: 5, backwards: false)
        XCTAssertEqual(selection.index, 0)
        selection.begin(count: 5, backwards: true)
        XCTAssertEqual(selection.index, 4)
    }
    func testSwitcherNoCurrentWindowAndEmptyList() {
        var selection = SwitcherSelection()
        selection.begin(count: 3, backwards: false, currentIsFirst: false)
        XCTAssertEqual(selection.index, 0)
        selection.begin(count: 0, backwards: true)
        selection.advance(count: 0, backwards: true)
        XCTAssertEqual(selection.index, 0)
        selection.begin(count: 1, backwards: false)
        XCTAssertEqual(selection.index, 0)
    }
    func testShortcutMatchingIgnoresCapsLockButRequiresExactModifiers() {
        let shortcut = Shortcut(keyCode: 123, modifiers: CGEventFlags([.maskControl, .maskAlternate]).rawValue)
        XCTAssertTrue(shortcut.matches(code: 123, flags: [.maskControl, .maskAlternate, .maskAlphaShift]))
        XCTAssertFalse(shortcut.matches(code: 123, flags: [.maskControl, .maskAlternate, .maskCommand]))
        XCTAssertFalse(shortcut.matches(code: 124, flags: [.maskControl, .maskAlternate]))
        XCTAssertEqual(shortcut.label, "⌃⌥←")
    }
    func testDefaultShortcutsAreUniqueAndRoundTrip() throws {
        XCTAssertEqual(Set(Shortcut.defaults.values).count, Shortcut.defaults.count)
        let data = try JSONEncoder().encode(Shortcut.defaults)
        XCTAssertEqual(try JSONDecoder().decode([WindowCommand: Shortcut].self, from: data), Shortcut.defaults)
    }
}
