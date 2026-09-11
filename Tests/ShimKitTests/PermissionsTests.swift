import XCTest
@testable import ShimKit

final class PermissionsTests: XCTestCase {
    func testFirstRequestUsesOnlyPromptAndRetryUsesOnlySettings() async {
        await MainActor.run {
            let name = "ShimKitTests.Permissions.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: name)!
            defer { defaults.removePersistentDomain(forName: name) }
            var prompts = 0
            var panes: [String] = []
            let manager = PermissionsManager(defaults: defaults, checkAccessibility: { false }, checkScreenRecording: { false },
                promptAccessibility: { prompts += 1 }, promptScreenRecording: { prompts += 10 }, openPane: { panes.append($0) })
            defer { manager.stopMonitoring() }
            manager.requestAccessibility()
            XCTAssertEqual(prompts, 1)
            XCTAssertTrue(panes.isEmpty, "Do not open Settings on top of the native prompt")
            XCTAssertEqual(manager.pending, .accessibility)
            manager.requestAccessibility()
            XCTAssertEqual(prompts, 1)
            XCTAssertEqual(panes, ["Privacy_Accessibility"])
            manager.requestScreenRecording()
            XCTAssertEqual(prompts, 11)
            XCTAssertEqual(panes.count, 1)
            manager.requestScreenRecording()
            XCTAssertEqual(prompts, 11)
            XCTAssertEqual(panes.last, "Privacy_ScreenCapture")
        }
    }
    func testGrantAndRevocationCallbacksRunOncePerChange() async {
        await MainActor.run {
            var accessibility = false
            var capture = false
            var grants = 0
            var revocations = 0
            var captureChanges: [Bool] = []
            let manager = PermissionsManager(checkAccessibility: { accessibility }, checkScreenRecording: { capture },
                promptAccessibility: {}, promptScreenRecording: {}, openPane: { _ in })
            manager.onAccessibilityGranted = { grants += 1 }
            manager.onAccessibilityRevoked = { revocations += 1 }
            manager.onScreenRecordingChanged = { captureChanges.append($0) }
            accessibility = true; capture = true
            manager.refresh(); manager.refresh()
            XCTAssertTrue(manager.accessibility)
            XCTAssertTrue(manager.screenRecording)
            XCTAssertEqual(grants, 1)
            XCTAssertEqual(captureChanges, [true])
            accessibility = false; capture = false
            manager.refresh(); manager.refresh()
            XCTAssertEqual(revocations, 1)
            XCTAssertEqual(captureChanges, [true, false])
        }
    }
    func testGrantedPermissionsNeverPromptAndMonitoringCanStop() async {
        await MainActor.run {
            var unexpected = 0
            let manager = PermissionsManager(checkAccessibility: { true }, checkScreenRecording: { true },
                promptAccessibility: { unexpected += 1 }, promptScreenRecording: { unexpected += 1 }, openPane: { _ in unexpected += 1 })
            manager.requestAccessibility(); manager.requestScreenRecording()
            XCTAssertEqual(unexpected, 0)
            XCTAssertNil(manager.pending)
            manager.monitorChanges()
            XCTAssertTrue(manager.isMonitoring)
            manager.stopMonitoring()
            XCTAssertFalse(manager.isMonitoring)
        }
    }
    func testGrantClearsWaitingStateWithoutManualRefreshButton() async {
        await MainActor.run {
            let name = "ShimKitTests.Waiting.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: name)!
            defer { defaults.removePersistentDomain(forName: name) }
            var granted = false
            let manager = PermissionsManager(defaults: defaults, checkAccessibility: { granted }, checkScreenRecording: { false },
                promptAccessibility: {}, promptScreenRecording: {}, openPane: { _ in })
            defer { manager.stopMonitoring() }
            manager.requestAccessibility()
            XCTAssertEqual(manager.pending, .accessibility)
            granted = true
            manager.refresh()
            XCTAssertNil(manager.pending)
            XCTAssertTrue(manager.accessibility)
        }
    }
}
