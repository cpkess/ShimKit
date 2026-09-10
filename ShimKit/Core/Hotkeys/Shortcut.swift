import AppKit

struct Shortcut: Codable, Equatable, Hashable {
    let keyCode: UInt16
    let modifiers: UInt64
    static let relevantFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
    var flags: CGEventFlags { CGEventFlags(rawValue: modifiers) }
    var eventModifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: UInt(modifiers)) }
    var label: String {
        var text = ""
        if flags.contains(.maskControl) { text += "⌃" }
        if flags.contains(.maskAlternate) { text += "⌥" }
        if flags.contains(.maskShift) { text += "⇧" }
        if flags.contains(.maskCommand) { text += "⌘" }
        return text + (Self.keys.first { $0.code == keyCode }?.label ?? "Key \(keyCode)")
    }
    var keyEquivalent: String { Self.keys.first { $0.code == keyCode }?.equivalent ?? "" }
    func matches(code: UInt16, flags: CGEventFlags) -> Bool {
        keyCode == code && flags.intersection(Self.relevantFlags).rawValue == modifiers
    }

    struct Key {
        let code: UInt16
        let label: String
        let equivalent: String
    }
    static let keys: [Key] = [
        Key(code: 50, label: "`", equivalent: "`"),
        Key(code: 123, label: "←", equivalent: "\u{F702}"), Key(code: 124, label: "→", equivalent: "\u{F703}"),
        Key(code: 126, label: "↑", equivalent: "\u{F700}"), Key(code: 125, label: "↓", equivalent: "\u{F701}"),
        Key(code: 0, label: "A", equivalent: "a"), Key(code: 8, label: "C", equivalent: "c"),
        Key(code: 2, label: "D", equivalent: "d"), Key(code: 3, label: "F", equivalent: "f"),
        Key(code: 4, label: "H", equivalent: "h"), Key(code: 34, label: "I", equivalent: "i"),
        Key(code: 38, label: "J", equivalent: "j"), Key(code: 40, label: "K", equivalent: "k"),
        Key(code: 37, label: "L", equivalent: "l"), Key(code: 31, label: "O", equivalent: "o"),
        Key(code: 35, label: "P", equivalent: "p"), Key(code: 15, label: "R", equivalent: "r"),
        Key(code: 1, label: "S", equivalent: "s"), Key(code: 32, label: "U", equivalent: "u"),
        Key(code: 9, label: "V", equivalent: "v"), Key(code: 13, label: "W", equivalent: "w"),
        Key(code: 7, label: "X", equivalent: "x"), Key(code: 16, label: "Y", equivalent: "y"),
        Key(code: 6, label: "Z", equivalent: "z")
    ]
    static let menuBarHider = Shortcut(keyCode: 4, modifiers: CGEventFlags([.maskControl, .maskAlternate]).rawValue)
    static let switcher = Shortcut(keyCode: 48, modifiers: CGEventFlags.maskAlternate.rawValue)
    static let applicationSwitcher = Shortcut(keyCode: 50, modifiers: CGEventFlags.maskCommand.rawValue)
    static let defaults: [WindowCommand: Shortcut] = {
        let codes: [WindowCommand: UInt16] = [.left: 123, .right: 124, .maximize: 126, .restore: 125,
            .topLeft: 32, .topRight: 34, .bottomLeft: 38, .bottomRight: 40, .center: 8]
        return codes.mapValues { Shortcut(keyCode: $0, modifiers: CGEventFlags([.maskControl, .maskAlternate]).rawValue) }
    }()
}

final class ShortcutStore: ObservableObject {
    @Published private(set) var bindings: [WindowCommand: Shortcut]
    init() {
        if let data = UserDefaults.standard.data(forKey: "shortcuts"),
           let saved = try? JSONDecoder().decode([WindowCommand: Shortcut].self, from: data) { bindings = saved }
        else { bindings = Shortcut.defaults }
    }
    func update(_ command: WindowCommand, shortcut: Shortcut?) -> String? {
        if let shortcut {
            if WindowSwitcherScope.matching(keyCode: shortcut.keyCode, flags: shortcut.flags) != nil {
                return "That shortcut is reserved for window switching."
            }
            guard shortcut.flags.contains(.maskControl) || shortcut.flags.contains(.maskAlternate) || shortcut.flags.contains(.maskCommand) else {
                return "Include Control, Option, or Command."
            }
            if bindings.contains(where: { $0.key != command && $0.value == shortcut }) { return "That shortcut is already assigned in ShimKit." }
        }
        bindings[command] = shortcut
        save()
        return nil
    }
    func reset() { bindings = Shortcut.defaults; save() }
    private func save() {
        if let data = try? JSONEncoder().encode(bindings) { UserDefaults.standard.set(data, forKey: "shortcuts") }
    }
}
