import AppKit

struct Shortcut: Codable, Equatable, Hashable {
    let keyCodes: [UInt16]
    var keyCode: UInt16 { keyCodes[0] }
    init(keyCode: UInt16, modifiers: UInt64) { self.keyCodes = [keyCode]; self.modifiers = modifiers }
    init(keyCodes: [UInt16], modifiers: UInt64) { self.keyCodes = keyCodes; self.modifiers = modifiers }
    private enum CodingKeys: String, CodingKey { case keyCode, keyCodes, modifiers }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCodes = try container.decodeIfPresent([UInt16].self, forKey: .keyCodes) ?? [container.decode(UInt16.self, forKey: .keyCode)]
        modifiers = try container.decode(UInt64.self, forKey: .modifiers)
        guard (1...4).contains(keyCodes.count) else {
            throw DecodingError.dataCorruptedError(forKey: .keyCodes, in: container, debugDescription: "Shortcuts need one to four keys")
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCodes, forKey: .keyCodes)
        try container.encode(modifiers, forKey: .modifiers)
    }
    func overlapsPrefix(with other: Shortcut) -> Bool {
        modifiers == other.modifiers && (keyCodes.starts(with: other.keyCodes) || other.keyCodes.starts(with: keyCodes))
    }
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
        return text + keyCodes.map { code in Self.keys.first { $0.code == code }?.label ?? "Key \(code)" }.joined(separator: ", ")
    }
    var keyEquivalent: String { guard keyCodes.count == 1 else { return "" }; return Self.keys.first { $0.code == keyCode }?.equivalent ?? "" }
    func matches(code: UInt16, flags: CGEventFlags) -> Bool {
        keyCodes.count == 1 && keyCode == code && flags.intersection(Self.relevantFlags).rawValue == modifiers
    }

    struct Key {
        let code: UInt16
        let label: String
        let equivalent: String
    }
    static let keys: [Key] = [
        Key(code: 11, label: "B", equivalent: "b"), Key(code: 14, label: "E", equivalent: "e"),
        Key(code: 5, label: "G", equivalent: "g"), Key(code: 46, label: "M", equivalent: "m"),
        Key(code: 45, label: "N", equivalent: "n"), Key(code: 12, label: "Q", equivalent: "q"),
        Key(code: 17, label: "T", equivalent: "t"),
        Key(code: 18, label: "1", equivalent: "1"), Key(code: 19, label: "2", equivalent: "2"),
        Key(code: 20, label: "3", equivalent: "3"), Key(code: 21, label: "4", equivalent: "4"),
        Key(code: 23, label: "5", equivalent: "5"), Key(code: 22, label: "6", equivalent: "6"),
        Key(code: 26, label: "7", equivalent: "7"), Key(code: 28, label: "8", equivalent: "8"),
        Key(code: 25, label: "9", equivalent: "9"), Key(code: 29, label: "0", equivalent: "0"),
        Key(code: 49, label: "Space", equivalent: " "), Key(code: 48, label: "Tab", equivalent: "\t"),
        Key(code: 36, label: "Return", equivalent: "\r"), Key(code: 51, label: "Delete", equivalent: ""),
        Key(code: 53, label: "Escape", equivalent: ""),
        Key(code: 27, label: "−", equivalent: "-"), Key(code: 24, label: "=", equivalent: "="),
        Key(code: 33, label: "[", equivalent: "["), Key(code: 30, label: "]", equivalent: "]"),
        Key(code: 41, label: ";", equivalent: ";"), Key(code: 39, label: "'", equivalent: "'"),
        Key(code: 43, label: ",", equivalent: ","), Key(code: 47, label: ".", equivalent: "."),
        Key(code: 44, label: "/", equivalent: "/"),

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
    ] + [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90].enumerated().map {
        Key(code: UInt16($0.element), label: "F\($0.offset + 1)", equivalent: String(UnicodeScalar(0xF704 + $0.offset)!))
    }
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
    @Published var isRecording = false
    private let defaults: UserDefaults
    @Published private(set) var bindings: [WindowCommand: Shortcut]
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "shortcuts"),
           let saved = try? JSONDecoder().decode([WindowCommand: Shortcut].self, from: data) { bindings = saved }
        else { bindings = Shortcut.defaults }
    }
    func update(_ command: WindowCommand, shortcut: Shortcut?) -> String? {
        if let shortcut {
            guard (1...4).contains(shortcut.keyCodes.count) else { return "Record one to four keys." }
            if shortcut.keyCodes.contains(where: { WindowSwitcherScope.matching(keyCode: $0, flags: shortcut.flags) != nil }) {
                return "That shortcut is reserved for window switching."
            }
            guard shortcut.flags.contains(.maskControl) || shortcut.flags.contains(.maskAlternate) || shortcut.flags.contains(.maskCommand) else {
                return "Include Control, Option, or Command."
            }
            if let conflict = bindings.first(where: { $0.key != command && $0.value.overlapsPrefix(with: shortcut) }) {
                return "This overlaps \(conflict.key.title) (\(conflict.value.label)). Change one binding so each sequence is unambiguous."
            }
        }
        bindings[command] = shortcut
        save()
        return nil
    }
    func reset() { bindings = Shortcut.defaults; save() }
    private func save() {
        if let data = try? JSONEncoder().encode(bindings) { defaults.set(data, forKey: "shortcuts") }
    }
}

/// Prefix conflicts are rejected by ShortcutStore, so single-key actions never wait.
struct ShortcutSequenceMatcher {
    private var pending: [UInt16] = []
    private var modifiers: UInt64 = 0
    private var lastTime: TimeInterval = 0
    mutating func reset() { pending.removeAll() }
    mutating func modifiersChanged(_ flags: CGEventFlags) {
        if flags.intersection(Shortcut.relevantFlags).rawValue != modifiers { reset() }
    }
    mutating func press(_ key: UInt16, flags: CGEventFlags, time: TimeInterval,
                        bindings: [WindowCommand: Shortcut]) -> (consumed: Bool, command: WindowCommand?) {
        let mask = flags.intersection(Shortcut.relevantFlags).rawValue
        if time - lastTime > 1.5 || mask != modifiers { reset() }
        modifiers = mask
        lastTime = time
        pending.append(key)
        var candidates = bindings.filter { $0.value.modifiers == mask && $0.value.keyCodes.starts(with: pending) }
        if candidates.isEmpty {
            pending = [key]
            candidates = bindings.filter { $0.value.modifiers == mask && $0.value.keyCodes.starts(with: pending) }
        }
        guard !candidates.isEmpty else { reset(); return (false, nil) }
        if let command = candidates.first(where: { $0.value.keyCodes == pending })?.key {
            reset()
            return (true, command)
        }
        return (true, nil)
    }
}
