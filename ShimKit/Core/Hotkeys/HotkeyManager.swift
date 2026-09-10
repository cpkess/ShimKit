import AppKit
import ApplicationServices

final class HotkeyManager: ObservableObject {
    @Published private(set) var status = "Waiting for Accessibility permission"
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var swallowed = Set<UInt16>()
    let shortcuts: ShortcutStore
    var onCommand: ((WindowCommand) -> Void)?
    var onSwitch: ((Bool, WindowSwitcherScope?) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var activeSwitcherScope: (() -> WindowSwitcherScope?)?

    init(shortcuts: ShortcutStore) { self.shortcuts = shortcuts }
    deinit { stop() }

    func start() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<HotkeyManager>.fromOpaque(context).takeUnretainedValue().handle(type, event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            status = "Keyboard access unavailable. Check Accessibility permission, then retry."
            Log.hotkeys.error("Unable to create keyboard event tap")
            return
        }
        tap = created
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: created, enable: true)
        status = "Global shortcuts active"
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil; swallowed.removeAll()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            onCancel?()
            swallowed.removeAll()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyUp, swallowed.remove(code) != nil { return nil }
        let scope = activeSwitcherScope?()
        if type == .flagsChanged, let scope, scope.shouldCommit(flags: event.flags) {
            onCommit?()
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        let flags = event.flags.intersection(Shortcut.relevantFlags)
        if Preferences.shared.switcherEnabled,
           let requestedScope = WindowSwitcherScope.matching(keyCode: code, flags: flags) {
            onSwitch?(flags.contains(.maskShift), requestedScope)
            swallowed.insert(code)
            return nil
        }
        if scope != nil {
            switch code {
            case 53: onCancel?()
            case 36, 76: onCommit?()
            case 123: onSwitch?(true, nil)
            case 124: onSwitch?(false, nil)
            default: return Unmanaged.passUnretained(event)
            }
            swallowed.insert(code)
            return nil
        }
        if Preferences.shared.managerEnabled,
           let command = shortcuts.bindings.first(where: { $0.value.matches(code: code, flags: flags) })?.key {
            // Never perform synchronous cross-process AX calls inside the event-tap callback.
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                DispatchQueue.main.async { [weak self] in self?.onCommand?(command) }
            }
            swallowed.insert(code)
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
}
