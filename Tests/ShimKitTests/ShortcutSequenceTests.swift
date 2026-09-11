import XCTest
import AppKit
@testable import ShimKit

final class ShortcutSequenceTests: XCTestCase {
    private let flags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
    private var twoKeys: Shortcut { Shortcut(keyCodes: [123, 126], modifiers: flags.rawValue) }

    func testExampleFiresOnlyAfterBothKeysAndCanBeRepeated() {
        var matcher = ShortcutSequenceMatcher()
        let bindings: [WindowCommand: Shortcut] = [.leftTwoThirds: twoKeys]
        let first = matcher.press(123, flags: flags, time: 0, bindings: bindings)
        XCTAssertTrue(first.consumed)
        XCTAssertNil(first.command)
        XCTAssertEqual(matcher.press(126, flags: flags, time: 0.2, bindings: bindings).command, .leftTwoThirds)
        XCTAssertFalse(matcher.press(126, flags: flags, time: 0.3, bindings: bindings).consumed)
        XCTAssertTrue(matcher.press(123, flags: flags, time: 0.4, bindings: bindings).consumed)
        XCTAssertEqual(matcher.press(126, flags: flags, time: 0.5, bindings: bindings).command, .leftTwoThirds)
    }
    func testTimeoutModifierReleaseAndWrongKeyCancelSequence() {
        for reason in 0..<3 {
            var matcher = ShortcutSequenceMatcher()
            let bindings: [WindowCommand: Shortcut] = [.leftTwoThirds: twoKeys]
            _ = matcher.press(123, flags: flags, time: 0, bindings: bindings)
            if reason == 1 { matcher.modifiersChanged(.maskAlternate) }
            if reason == 2 { XCTAssertFalse(matcher.press(0, flags: flags, time: 0.1, bindings: bindings).consumed) }
            XCTAssertNil(matcher.press(126, flags: flags, time: reason == 0 ? 2 : 0.2, bindings: bindings).command)
        }
    }
    func testBranchingSequencesAndSinglesStayImmediate() {
        var matcher = ShortcutSequenceMatcher()
        let bindings: [WindowCommand: Shortcut] = [
            .leftTwoThirds: twoKeys,
            .rightTwoThirds: Shortcut(keyCodes: [123, 125], modifiers: flags.rawValue),
            .maximize: Shortcut(keyCode: 0, modifiers: flags.rawValue)]
        _ = matcher.press(123, flags: flags, time: 0, bindings: bindings)
        XCTAssertEqual(matcher.press(125, flags: flags, time: 0.1, bindings: bindings).command, .rightTwoThirds)
        XCTAssertEqual(matcher.press(0, flags: flags, time: 0.2, bindings: bindings).command, .maximize)
    }
    func testLegacyShortcutDecodesAndSequencesRoundTrip() throws {
        let old = Data("{\"keyCode\":123,\"modifiers\":786432}".utf8)
        XCTAssertEqual(try JSONDecoder().decode(Shortcut.self, from: old).keyCodes, [123])
        XCTAssertEqual(try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(twoKeys)), twoKeys)
        XCTAssertEqual(twoKeys.label, "⌃⌥⌘←, ↑")
        XCTAssertEqual(twoKeys.keyEquivalent, "", "Menus must not register the first key as the whole sequence")
        XCTAssertFalse(twoKeys.matches(code: 123, flags: flags))
        XCTAssertThrowsError(try JSONDecoder().decode(Shortcut.self, from: Data("{\"keyCodes\":[],\"modifiers\":0}".utf8)))
    }
    func testStoreRejectsPrefixesAndReservedKeysAndPersists() {
        let name = "ShimKitTests.Sequences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ShortcutStore(defaults: defaults)
        XCTAssertNil(store.update(.leftTwoThirds, shortcut: twoKeys))
        XCTAssertNotNil(store.update(.rightTwoThirds, shortcut: twoKeys))
        XCTAssertNotNil(store.update(.rightTwoThirds, shortcut: Shortcut(keyCode: 123, modifiers: flags.rawValue)))
        XCTAssertNotNil(store.update(.rightTwoThirds, shortcut: Shortcut(keyCodes: [123, 126, 125], modifiers: flags.rawValue)))
        XCTAssertNotNil(store.update(.rightTwoThirds, shortcut: Shortcut(keyCodes: [0, 48], modifiers: CGEventFlags.maskAlternate.rawValue)))
        XCTAssertEqual(ShortcutStore(defaults: defaults).bindings[.leftTwoThirds], twoKeys)
    }
    func testRecorderConsumesKeysAndStopsOnModifierRelease() async throws {
        try await MainActor.run {
            _ = NSApplication.shared
            let name = "ShimKitTests.Recorder.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: name)!
            defer { defaults.removePersistentDomain(forName: name) }
            let store = ShortcutStore(defaults: defaults)
            let recorder = ShortcutRecorder()
            recorder.start(store: store)
            defer { recorder.stop() }
            func event(_ type: NSEvent.EventType, _ code: UInt16, _ modifiers: NSEvent.ModifierFlags, repeatKey: Bool = false) throws -> NSEvent {
                try XCTUnwrap(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: modifiers,
                    timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: repeatKey, keyCode: code))
            }
            XCTAssertTrue(store.isRecording)
            XCTAssertNil(recorder.handle(try event(.keyDown, 123, [.control, .option, .command])))
            XCTAssertNil(recorder.handle(try event(.keyDown, 123, [.control, .option, .command], repeatKey: true)))
            XCTAssertNil(recorder.handle(try event(.keyDown, 126, [.control, .option, .command])))
            XCTAssertEqual(recorder.recorded?.keyCodes, [123, 126])
            _ = recorder.handle(try event(.flagsChanged, 59, [.option, .command]))
            XCTAssertFalse(store.isRecording)
            XCTAssertFalse(recorder.isRecording)
        }
    }
}
