import AppKit

final class ShortcutRecorder: ObservableObject {
    @Published var recorded: Shortcut?
    @Published private(set) var isRecording = false
    @Published private(set) var message = ""
    private var monitor: Any?
    private var store: ShortcutStore?
    private var codes: [UInt16] = []
    private var flags: CGEventFlags = []
    private var previous: Shortcut?

    func start(store: ShortcutStore) {
        stop()
        self.store = store
        previous = recorded
        codes = []
        flags = []
        message = "Hold the modifiers and all shortcut keys together. Release a key to finish."
        isRecording = true
        store.isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }
    func stop(cancel: Bool = false) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        store?.isRecording = false
        store = nil
        isRecording = false
        if cancel { recorded = previous }
    }
    func handle(_ event: NSEvent) -> NSEvent? {
        if event.type == .flagsChanged {
            let current = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)).intersection(Shortcut.relevantFlags)
            if !codes.isEmpty, current != flags {
                let releasedOnly = current.intersection(flags) == current
                stop(cancel: !releasedOnly)
                message = releasedOnly ? "Recorded. Save to assign this combination." : "Modifiers changed. Record the combination again."
            }
            return event
        }
        if event.type == .keyUp {
            if codes.contains(event.keyCode) {
                stop()
                message = "Recorded. Save to assign this combination."
            }
            return nil
        }
        if event.isARepeat { return nil }
        let current = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)).intersection(Shortcut.relevantFlags)
        if event.keyCode == 53 && current.isEmpty { stop(cancel: true); message = "Recording cancelled."; return nil }
        guard !current.intersection([.maskControl, .maskAlternate, .maskCommand]).isEmpty else {
            message = "Include Control, Option, or Command. Escape cancels."
            return nil
        }
        guard codes.isEmpty || current == flags else {
            message = "Keep the same modifiers held for every key."
            return nil
        }
        guard codes.count < 4 else { message = "Four keys recorded. Release the modifiers to finish."; return nil }
        flags = current
        if !codes.contains(event.keyCode) { codes.append(event.keyCode) }
        recorded = Shortcut(keyCodes: codes, modifiers: flags.rawValue)
        return nil
    }
    deinit { if let monitor { NSEvent.removeMonitor(monitor) }; store?.isRecording = false }
}
