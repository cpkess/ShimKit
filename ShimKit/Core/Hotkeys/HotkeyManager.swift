import AppKit
import ApplicationServices

final class HotkeyManager: ObservableObject {
    @Published private(set) var status = "Waiting for Accessibility permission"
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var activationObserver: NSObjectProtocol?
    private var sequence = ShortcutSequenceMatcher()
    private var swallowed = Set<UInt16>()
    let shortcuts: ShortcutStore
    var onToggleMenuBar: (() -> Void)?
    var onCommand: ((WindowCommand) -> Void)?
    var onSwitch: ((Bool, WindowSwitcherScope?) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var activeSwitcherScope: (() -> WindowSwitcherScope?)?

    init(shortcuts: ShortcutStore) {
        self.shortcuts = shortcuts
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { [weak self] _ in self?.sequence.reset() }
    }
    deinit {
        stop()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }

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
        tap = nil; source = nil; swallowed.removeAll(); sequence.reset()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            onCancel?()
            swallowed.removeAll(); sequence.reset()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyUp, swallowed.remove(code) != nil { return nil }
        if shortcuts.isRecording { sequence.reset(); return Unmanaged.passUnretained(event) }
        if type == .flagsChanged { sequence.modifiersChanged(event.flags) }
        if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            return swallowed.contains(code) ? nil : Unmanaged.passUnretained(event)
        }
        let scope = activeSwitcherScope?()
        if type == .flagsChanged, let scope, scope.shouldCommit(flags: event.flags) {
            onCommit?()
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        let flags = event.flags.intersection(Shortcut.relevantFlags)
        if Preferences.shared.switcherEnabled,
           let requestedScope = WindowSwitcherScope.matching(keyCode: code, flags: flags) {
            sequence.reset()
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
        if Preferences.shared.managerEnabled {
            let result = sequence.press(code, flags: flags, time: ProcessInfo.processInfo.systemUptime, bindings: shortcuts.bindings)
            if result.consumed {
                if let command = result.command, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                    DispatchQueue.main.async { [weak self] in self?.onCommand?(command) }
                }
                swallowed.insert(code)
                return nil
            }
        } else { sequence.reset() }
        if Preferences.shared.menuBarHiderEnabled, Preferences.shared.menuBarHiderHotkey,
           !shortcuts.bindings.values.contains(where: { $0.overlapsPrefix(with: .menuBarHider) }),
           Shortcut.menuBarHider.matches(code: code, flags: flags) {
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                DispatchQueue.main.async { [weak self] in self?.onToggleMenuBar?() }
            }
            swallowed.insert(code)
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
}
