import XCTest
import AppKit
import ApplicationServices
@testable import ShimKit

final class SwitcherPanelTests: XCTestCase {
    func testCachedPreviewsAreInstalledDuringPresentation() async throws {
        try await MainActor.run {
            _ = NSApplication.shared
            guard let screen = NSScreen.main else { throw XCTSkip("A display is required") }
            let panel = SwitcherPanel()
            let names = ["Safari", "Notes", "Xcode"]
            let titles = ["Designing a calmer workspace", "Ideas for the week", "ShimKit — SwitcherPanel.swift"]
            let windows = names.enumerated().map { index, name in
                WindowInfo(id: WindowKey(pid: pid_t(index + 100), element: AXUIElementCreateApplication(pid_t(index + 100))),
                           appName: name, title: titles[index], frame: CGRect(x: 0, y: 0, width: 800, height: 500), minimized: false)
            }
            var delivered = 0
            panel.present(windows, selected: 1, screen: screen, previewFor: { key in
                delivered += 1
                let image = NSImage(size: NSSize(width: 384, height: 240))
                image.lockFocus()
                NSColor.windowBackgroundColor.setFill()
                NSRect(x: 0, y: 0, width: 384, height: 240).fill()
                let colors: [NSColor] = [.systemBlue, .systemOrange, .systemIndigo]
                colors[Int(key.pid) - 100].withAlphaComponent(0.18).setFill()
                NSRect(x: 0, y: 148, width: 384, height: 92).fill()
                (names[Int(key.pid) - 100] as NSString).draw(at: NSPoint(x: 24, y: 175), withAttributes: [.font: NSFont.systemFont(ofSize: 25, weight: .semibold), .foregroundColor: NSColor.labelColor])
                for row in 0..<5 {
                    NSColor.secondaryLabelColor.withAlphaComponent(0.18).setFill()
                    NSBezierPath(roundedRect: NSRect(x: 24, y: 118 - row * 20, width: row == 4 ? 175 : 330, height: 6), xRadius: 3, yRadius: 3).fill()
                }
                image.unlockFocus()
                return image
            })
            defer { panel.clear() }
            XCTAssertEqual(delivered, windows.count, "Previews must be supplied before presentation returns, without an asynchronous capture")
            panel.contentView?.layoutSubtreeIfNeeded()
            if let view = panel.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "/tmp/shimkit-switcher-design.png"))
            }
        }
    }

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
