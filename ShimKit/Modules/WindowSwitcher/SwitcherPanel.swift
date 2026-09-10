import AppKit

final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    private let scroll = NSScrollView()
    private let stack = NSStackView()
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
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = 20
        material.layer?.masksToBounds = true
        contentView = material
        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.horizontalScrollElasticity = .allowed
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .top
        scroll.documentView = stack
        material.addSubview(scroll)
        material.addSubview(message)
        message.alignment = .center
        message.font = .systemFont(ofSize: 14)
        message.textColor = .secondaryLabelColor
    }

    func present(_ windows: [WindowInfo], selected: Int, screen: NSScreen) {
        cards.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        cards = windows.enumerated().map { index, window in
            let card = WindowCard(window: window)
            card.onClick = { [weak self] in self?.onChoose?(index) }
            stack.addArrangedSubview(card)
            return card
        }
        let available = screen.visibleFrame
        let width = min(max(340, CGFloat(windows.count) * 190 + 38), max(300, available.width - 80))
        let height: CGFloat = windows.isEmpty ? 110 : 240
        setFrame(NSRect(x: available.midX - width / 2, y: available.midY - height / 2,
                        width: width, height: height), display: false)
        scroll.frame = NSRect(x: 20, y: 22, width: width - 40, height: height - 40)
        stack.frame = NSRect(x: 0, y: 0, width: max(width - 40, CGFloat(windows.count) * 190 - 10), height: 190)
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
    private let icon = NSImageView()
    var onClick: (() -> Void)?

    init(window: WindowInfo) {
        key = window.id
        super.init(frame: NSRect(x: 0, y: 0, width: 180, height: 190))
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: 180), heightAnchor.constraint(equalToConstant: 190)])
        wantsLayer = true
        layer?.cornerRadius = 12
        let appIcon = NSRunningApplication(processIdentifier: window.pid)?.icon ?? NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        preview.image = appIcon
        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.frame = NSRect(x: 16, y: 68, width: 148, height: 104)
        addSubview(preview)
        icon.image = appIcon
        icon.frame = NSRect(x: 12, y: 39, width: 20, height: 20)
        addSubview(icon)
        let preferences = Preferences.shared
        let app = NSTextField(labelWithString: preferences.appNames ? window.appName : "")
        app.font = .systemFont(ofSize: 12, weight: .semibold)
        app.frame = NSRect(x: 38, y: 39, width: 130, height: 19)
        app.lineBreakMode = .byTruncatingTail
        addSubview(app)
        let title = NSTextField(labelWithString: preferences.windowTitles ? (window.title.isEmpty ? "Untitled window" : window.title) : "")
        title.font = .systemFont(ofSize: 11)
        title.textColor = .secondaryLabelColor
        title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: 12, y: 16, width: 156, height: 19)
        addSubview(title)
        toolTip = "\(window.appName) — \(window.title)\(window.minimized ? " (minimized)" : "")"
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(toolTip)
        if window.minimized {
            let badge = NSImageView(image: NSImage(systemSymbolName: "minus.rectangle", accessibilityDescription: "Minimized") ?? NSImage())
            badge.frame = NSRect(x: 147, y: 151, width: 18, height: 18)
            addSubview(badge)
        }
    }
    required init?(coder: NSCoder) { nil }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func accessibilityPerformPress() -> Bool { onClick?(); return true }
    func setSelected(_ selected: Bool) {
        layer?.backgroundColor = selected ? NSColor.controlAccentColor.withAlphaComponent(0.24).cgColor : NSColor.clear.cgColor
        layer?.borderWidth = selected ? 2 : 0
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
        setAccessibilityValue(selected ? "Selected" : "")
    }
    func setPreview(_ image: NSImage) { preview.image = image }
}
