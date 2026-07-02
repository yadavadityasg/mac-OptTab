import Cocoa

/// The floating "thumbnail bar" that appears while Option is held.
final class SwitcherPanel: NSPanel {
    private var stackView: NSStackView!
    private var itemViews: [WindowItemView] = []
    private var currentWindows: [WindowInfo] = []
    private(set) var selectedIndex: Int = 0

    convenience init() {
        let initialRect = NSRect(x: 0, y: 0, width: 400, height: 140)
        self.init(
            contentRect: initialRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false

        let visualEffect = NSVisualEffectView(frame: initialRect)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        contentView = visualEffect

        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 12
        stackView.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: visualEffect.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor)
        ])
    }

    func show(windows: [WindowInfo], selecting index: Int) {
        currentWindows = windows
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews = windows.map { WindowItemView(window: $0) }
        itemViews.forEach { stackView.addArrangedSubview($0) }

        let itemWidth: CGFloat = 96
        let width = min(CGFloat(windows.count) * (itemWidth + 12) + 32, 900)
        setContentSize(NSSize(width: max(width, 200), height: 140))
        centerOnActiveScreen()

        select(index: index)
        orderFrontRegardless()
    }

    func select(index: Int) {
        guard !currentWindows.isEmpty else { return }
        let count = currentWindows.count
        let clamped = ((index % count) + count) % count
        selectedIndex = clamped
        for (i, view) in itemViews.enumerated() {
            view.setHighlighted(i == clamped)
        }
    }

    func selectedWindow() -> WindowInfo? {
        guard selectedIndex < currentWindows.count else { return nil }
        return currentWindows[selectedIndex]
    }

    func hidePanel() {
        orderOut(nil)
    }

    private func centerOnActiveScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// One icon + title cell inside the switcher bar.
final class WindowItemView: NSView {
    private let imageView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let background = NSView()

    init(window: WindowInfo) {
        super.init(frame: NSRect(x: 0, y: 0, width: 96, height: 108))
        wantsLayer = true

        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.backgroundColor = NSColor.clear.cgColor
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        imageView.image = window.appIcon
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        label.stringValue = window.title.isEmpty ? window.ownerName : window.title
        label.font = .systemFont(ofSize: 11)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            imageView.widthAnchor.constraint(equalToConstant: 48),
            imageView.heightAnchor.constraint(equalToConstant: 48),

            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),

            widthAnchor.constraint(equalToConstant: 96),
            heightAnchor.constraint(equalToConstant: 108)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setHighlighted(_ highlighted: Bool) {
        background.layer?.backgroundColor = highlighted
            ? NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor
            : NSColor.clear.cgColor
    }
}
