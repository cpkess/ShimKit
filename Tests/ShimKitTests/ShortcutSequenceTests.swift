import XCTest
import AppKit
@testable import ShimKit

final class ShortcutChordTests: XCTestCase {
    private let flags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
    private var twoKeys: Shortcut { Shortcut(keyCodes: [123, 126], modifiers: flags.rawValue) }
    private var bindings: [WindowCommand: Shortcut] {
        [.left: Shortcut(keyCode: 123, modifiers: flags.rawValue), .leftTwoThirds: twoKeys]
    }
    func testAmbiguousSingleWaitsForRelease() {
        var matcher = ShortcutChordMatcher()
        XCTAssertNil(matcher.press(123, flags: flags, bindings: bindings).command)
        XCTAssertEqual(matcher.release(123), .left)
        XCTAssertNil(matcher.release(123))
    }
    func testLargerChordFiresImmediatelyInEitherOrderWithoutSmallerAction() {
        for keys: [UInt16] in [[123, 126], [126, 123]] {
            var matcher = ShortcutChordMatcher()
            XCTAssertNil(matcher.press(keys[0], flags: flags, bindings: bindings).command)
            XCTAssertEqual(matcher.press(keys[1], flags: flags, bindings: bindings).command, .leftTwoThirds)
            XCTAssertNil(matcher.release(keys[0]))
            XCTAssertNil(matcher.release(keys[1]))
            XCTAssertNil(matcher.modifiersChanged([]))
        }
    }
    func testUnambiguousSingleAndMultiKeyFireOnKeyDown() {
        var matcher = ShortcutChordMatcher()
        let single: [WindowCommand: Shortcut] = [.left: Shortcut(keyCode: 123, modifiers: flags.rawValue)]
        XCTAssertEqual(matcher.press(123, flags: flags, bindings: single).command, .left)
        XCTAssertNil(matcher.release(123))
        XCTAssertNil(matcher.press(126, flags: flags, bindings: [.leftTwoThirds: twoKeys]).command)
        XCTAssertEqual(matcher.press(123, flags: flags, bindings: [.leftTwoThirds: twoKeys]).command, .leftTwoThirds)
    }
    func testSequentialPressesDoNotFormChord() {
        var matcher = ShortcutChordMatcher()
        let only: [WindowCommand: Shortcut] = [.leftTwoThirds: twoKeys]
        XCTAssertNil(matcher.press(123, flags: flags, bindings: only).command)
        XCTAssertNil(matcher.release(123))
        XCTAssertNil(matcher.press(126, flags: flags, bindings: only).command)
        XCTAssertNil(matcher.release(126))
    }
    func testAmbiguousMultiKeyWaitsForReleaseAndLargerChordWins() {
        var matcher = ShortcutChordMatcher()
        var all = bindings
        all[.maximize] = Shortcut(keyCodes: [123, 126, 125], modifiers: flags.rawValue)
        _ = matcher.press(123, flags: flags, bindings: all)
        XCTAssertNil(matcher.press(126, flags: flags, bindings: all).command)
        XCTAssertEqual(matcher.release(123), .leftTwoThirds)
        XCTAssertNil(matcher.release(126))
        _ = matcher.press(126, flags: flags, bindings: all)
        _ = matcher.press(123, flags: flags, bindings: all)
        XCTAssertEqual(matcher.press(125, flags: flags, bindings: all).command, .maximize)
        XCTAssertNil(matcher.release(125))
    }
    func testModifierReleaseCompletesButAddedModifierAndWrongKeyCancel() {
        var matcher = ShortcutChordMatcher()
        _ = matcher.press(123, flags: flags, bindings: bindings)
        XCTAssertEqual(matcher.modifiersChanged(.maskAlternate), .left)
        XCTAssertNil(matcher.release(123))
        _ = matcher.press(123, flags: flags, bindings: bindings)
        XCTAssertNil(matcher.modifiersChanged(flags.union(.maskShift)))
        XCTAssertNil(matcher.release(123))
        _ = matcher.press(123, flags: flags, bindings: bindings)
        XCTAssertFalse(matcher.press(0, flags: flags, bindings: bindings).consumed)
        XCTAssertNil(matcher.release(123))
        XCTAssertNil(matcher.release(0))
    }
    func testLegacyMigrationAndOrderIndependentDuplicates() throws {
        let old = Data("{\"keyCode\":123,\"modifiers\":786432}".utf8)
        XCTAssertEqual(try JSONDecoder().decode(Shortcut.self, from: old).keyCodes, [123])
        XCTAssertEqual(twoKeys, Shortcut(keyCodes: [126, 123], modifiers: flags.rawValue))
        XCTAssertEqual(twoKeys.label, "⌃⌥⌘← + ↑")
        XCTAssertEqual(twoKeys.keyEquivalent, "")
        XCTAssertEqual(try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(twoKeys)), twoKeys)
        let name = "ShimKitTests.Chords.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ShortcutStore(defaults: defaults)
        store.replace(with: [:])
        XCTAssertNil(store.update(.left, shortcut: bindings[.left]))
        XCTAssertNil(store.update(.leftTwoThirds, shortcut: twoKeys))
        XCTAssertNotNil(store.update(.rightTwoThirds, shortcut: Shortcut(keyCodes: [126, 123], modifiers: flags.rawValue)))
        XCTAssertEqual(ShortcutStore(defaults: defaults).bindings[.leftTwoThirds], twoKeys)
    }
    func testRecorderConsumesKeysAndStopsOnFirstKeyRelease() async throws {
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
            _ = recorder.handle(try event(.keyUp, 123, [.control, .option, .command]))
            XCTAssertFalse(store.isRecording)
            XCTAssertFalse(recorder.isRecording)
        }
    }
}
