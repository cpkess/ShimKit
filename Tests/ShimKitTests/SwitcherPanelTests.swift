import XCTest
import AppKit
import ApplicationServices
@testable import ShimKit

final class SwitcherPanelTests: XCTestCase {
    func testLongWindowListScrollsToSelectionAndReleasesCards() async throws {
        try await MainActor.run {
            _ = NSApplication.shared
            guard let screen = NSScreen.main else { throw XCTSkip("A WindowServer display is required") }
            let panel = SwitcherPanel()
            let windows = (0..<20).map { index in
                WindowInfo(id: WindowKey(pid: ProcessInfo.processInfo.processIdentifier,
                                         element: AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)),
                           appName: "Fixture \(index)", title: "Window \(index)",
                           frame: CGRect(x: 0, y: 0, width: 800, height: 600), minimized: index == 2)
            }
            panel.present(windows, selected: 19, screen: screen)
            defer { panel.clear() }
            panel.contentView?.layoutSubtreeIfNeeded()
            let scroll = try XCTUnwrap(panel.contentView?.subviews.compactMap { $0 as? NSScrollView }.first)
            XCTAssertGreaterThan(scroll.contentView.bounds.minX, 0, "Keyboard selection must scroll into view")
            XCTAssertLessThanOrEqual(panel.frame.width, screen.visibleFrame.width)
            let stack = try XCTUnwrap(scroll.documentView as? NSStackView)
            XCTAssertEqual(stack.arrangedSubviews.count, 20)
            panel.clear()
            XCTAssertTrue(stack.arrangedSubviews.isEmpty, "Dismissal must release card images")
            XCTAssertFalse(panel.isVisible)
        }
    }
}
