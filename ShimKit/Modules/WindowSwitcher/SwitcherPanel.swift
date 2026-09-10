import AppKit

final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    private let scroll = NSScrollView()
    private let stack = NSStackView()
    private let heading = NSTextField(labelWithString: "")
    private let hint = NSTextField(labelWithString: "")
    private let message = NSTextField(labelWithString: "")
    private var cards: [WindowCard] = []
    var onChoose: ((Int) -> Void)?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        animationBehavior = .none
        let material = NSVisualEffectView()
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = 24
        material.layer?.borderWidth = 1
        material.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        material.layer?.masksToBounds = true
        contentView = material
        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.horizontalScrollElasticity = .allowed
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .top
        scroll.documentView = stack
        material.addSubview(scroll)
        material.addSubview(message)
        material.addSubview(heading)
        material.addSubview(hint)
        heading.font = .systemFont(ofSize: 12, weight: .semibold)
        heading.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center
        message.alignment = .center
        message.font = .systemFont(ofSize: 14)
        message.textColor = .secondaryLabelColor
    }

    func present(_ windows: [WindowInfo], selected: Int, screen: NSScreen, previewFor: ((WindowKey) -> NSImage?)? = nil, applicationOnly: Bool = false) {
        cards.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        cards = windows.enumerated().map { index, window in
            let card = WindowCard(window: window)
            if let image = previewFor?(window.id) { card.setPreview(image) }
            card.onClick = { [weak self] in self?.onChoose?(index) }
            stack.addArrangedSubview(card)
            return card
        }
        let available = screen.visibleFrame
        let width = min(max(340, CGFloat(windows.count) * 240 + 28), max(300, available.width - 80))
        let height: CGFloat = windows.isEmpty ? 140 : 294
        setFrame(NSRect(x: available.midX - width / 2, y: available.midY - height / 2,
                        width: width, height: height), display: false)
        scroll.frame = NSRect(x: 20, y: 40, width: width - 40, height: 214)
        stack.frame = NSRect(x: 0, y: 0, width: max(width - 40, CGFloat(windows.count) * 240 - 12), height: 204)
        heading.stringValue = "\(applicationOnly ? windows.first?.appName ?? "Application" : "All windows")  ·  \(windows.count)"
        heading.frame = NSRect(x: 24, y: height - 32, width: width - 48, height: 18)
        hint.stringValue = applicationOnly ? "Release ⌘ to switch   ·   ⇧ reverse   ·   esc cancel" : "Release ⌥ to switch   ·   ⇧ reverse   ·   esc cancel"
        hint.frame = NSRect(x: 20, y: 13, width: width - 40, height: 17)
        hint.isHidden = windows.isEmpty
        message.frame = NSRect(x: 20, y: 40, width: width - 40, height: 22)
        message.stringValue = windows.isEmpty ? "No eligible windows available" : ""
        scroll.isHidden = windows.isEmpty
        updateSelection(selected)
        orderFrontRegardless()
    }

    func updateSelection(_ selected: Int) {
        for (index, card) in cards.enumerated() { card.setSelected(index == selected) }
        if cards.indices.contains(selected) {
            stack.layoutSubtreeIfNeeded()
            stack.scrollToVisible(cards[selected].frame.insetBy(dx: -6, dy: 0))
        }
    }

    func setPreview(_ image: NSImage, for key: WindowKey) {
        cards.first { $0.key == key }?.setPreview(image)
    }
    func clear() {
        orderOut(nil)
        cards.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        cards.removeAll()
    }
}

private final class WindowCard: NSView {
    let key: WindowKey
    private let preview = NSImageView()
    private let placeholder = NSImageView()
    private let well = NSView()
    private var selected = false
    var onClick: (() -> Void)?

    init(window: WindowInfo) {
        key = window.id
        super.init(frame: NSRect(x: 0, y: 0, width: 228, height: 204))
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: 228), heightAnchor.constraint(equalToConstant: 204)])
        wantsLayer = true
        layer?.cornerRadius = 16
        let appIcon = NSRunningApplication(processIdentifier: window.pid)?.icon ?? NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        well.frame = NSRect(x: 8, y: 59, width: 212, height: 137)
        well.wantsLayer = true
        well.layer?.cornerRadius = 10
        well.layer?.masksToBounds = true
        addSubview(well)
        preview.frame = well.bounds.insetBy(dx: 5, dy: 5)
        preview.imageScaling = .scaleProportionallyUpOrDown
        well.addSubview(preview)
        placeholder.image = appIcon
        placeholder.imageScaling = .scaleProportionallyUpOrDown
        placeholder.frame = NSRect(x: 78, y: 40, width: 56, height: 56)
        well.addSubview(placeholder)
        let icon = NSImageView()
        icon.image = appIcon
        icon.frame = NSRect(x: 14, y: 19, width: 28, height: 28)
        addSubview(icon)
        let preferences = Preferences.shared
        let app = NSTextField(labelWithString: preferences.appNames ? window.appName : "")
        app.font = .systemFont(ofSize: 12, weight: .semibold)
        app.frame = NSRect(x: 50, y: 32, width: 164, height: 17)
        app.lineBreakMode = .byTruncatingTail
        addSubview(app)
        let title = NSTextField(labelWithString: preferences.windowTitles ? (window.title.isEmpty ? "Untitled window" : window.title) : "")
        title.font = .systemFont(ofSize: 11)
        title.textColor = .secondaryLabelColor
        title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: 50, y: 15, width: 164, height: 16)
        addSubview(title)
        toolTip = "\(window.appName) — \(window.title)\(window.minimized ? " (minimized)" : "")"
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(toolTip)
        if window.minimized {
            let badge = NSTextField(labelWithString: "Minimized")
            badge.font = .systemFont(ofSize: 10, weight: .medium)
            badge.textColor = .secondaryLabelColor
            badge.drawsBackground = true
            badge.backgroundColor = .windowBackgroundColor
            badge.wantsLayer = true
            badge.layer?.cornerRadius = 4
            badge.layer?.masksToBounds = true
            badge.frame = NSRect(x: 139, y: 8, width: 65, height: 16)
            well.addSubview(badge)
        }
        updateColors()
    }
    required init?(coder: NSCoder) { nil }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func accessibilityPerformPress() -> Bool { onClick?(); return true }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateColors() }
    func setSelected(_ selected: Bool) {
        self.selected = selected
        updateColors()
        setAccessibilityValue(selected ? "Selected" : "")
    }
    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = (selected ? NSColor.controlAccentColor.withAlphaComponent(0.10) : NSColor.clear).cgColor
            layer?.borderWidth = selected ? 1.5 : 0
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.75).cgColor
            well.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.045).cgColor
        }
    }
    func setPreview(_ image: NSImage) { preview.image = image; placeholder.isHidden = true }
}
