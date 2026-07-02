import Cocoa

/// Grid overview shown when Option is tapped alone (no Tab, no other key).
/// Lets you see every open window at a glance and click one to jump to it.
final class OverviewPanel: NSPanel {
    private var gridView: NSGridView?
    private var itemViews: [OverviewItemView] = []
    private var currentWindows: [WindowInfo] = []

    var onSelect: ((WindowInfo) -> Void)?
    var onDismiss: (() -> Void)?

    override var canBecomeKey: Bool { true }

    convenience init() {
        let initialRect = NSRect(x: 0, y: 0, width: 600, height: 400)
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
        visualEffect.layer?.cornerRadius = 20
        visualEffect.layer?.masksToBounds = true
        contentView = visualEffect
    }

    func show(windows: [WindowInfo], activeWindowID: CGWindowID?) {
        currentWindows = windows
        gridView?.removeFromSuperview()
        itemViews.forEach { $0.removeFromSuperview() }

        let columns = max(1, min(6, Int(ceil(sqrt(Double(windows.count))))))
        let rows = Int(ceil(Double(windows.count) / Double(columns)))

        itemViews = windows.map { window in
            let view = OverviewItemView(window: window, isActive: window.windowID == activeWindowID)
            view.onClick = { [weak self] in
                self?.onSelect?(window)
            }
            return view
        }

        let grid = NSGridView()
        grid.rowSpacing = 16
        grid.columnSpacing = 16
        grid.translatesAutoresizingMaskIntoConstraints = false

        var index = 0
        for _ in 0..<rows {
            var rowViews: [NSView] = []
            for _ in 0..<columns {
                if index < itemViews.count {
                    rowViews.append(itemViews[index])
                } else {
                    let filler = NSView()
                    filler.widthAnchor.constraint(equalToConstant: 140).isActive = true
                    filler.heightAnchor.constraint(equalToConstant: 120).isActive = true
                    rowViews.append(filler)
                }
                index += 1
            }
            grid.addRow(with: rowViews)
        }

        gridView = grid
        guard let content = contentView else { return }
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        ])

        content.layoutSubtreeIfNeeded()
        let fitting = grid.fittingSize
        let padding: CGFloat = 56
        setContentSize(NSSize(
            width: min(fitting.width + padding, 1200),
            height: min(fitting.height + padding, 820)
        ))

        centerOnActiveScreen()
        makeKeyAndOrderFront(nil)
    }

    func hidePanel() {
        orderOut(nil)
    }

    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }

    override func resignKey() {
        super.resignKey()
        onDismiss?()
    }

    private func centerOnActiveScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// One clickable window cell inside the overview grid.
final class OverviewItemView: NSView {
    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let appLabel = NSTextField(labelWithString: "")
    private let background = NSView()
    private var trackingArea: NSTrackingArea?

    var onClick: (() -> Void)?

    init(window: WindowInfo, isActive: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 140, height: 120))
        wantsLayer = true

        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        if isActive {
            background.layer?.borderWidth = 2
            background.layer?.borderColor = NSColor.controlAccentColor.cgColor
        }
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        imageView.image = window.appIcon
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        titleLabel.stringValue = window.title.isEmpty ? window.ownerName : window.title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        appLabel.stringValue = window.ownerName
        appLabel.font = .systemFont(ofSize: 10)
        appLabel.textColor = .secondaryLabelColor
        appLabel.alignment = .center
        appLabel.lineBreakMode = .byTruncatingTail
        appLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(appLabel)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            imageView.widthAnchor.constraint(equalToConstant: 48),
            imageView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),

            appLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            appLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            appLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            widthAnchor.constraint(equalToConstant: 140),
            heightAnchor.constraint(equalToConstant: 120)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func mouseEntered(with event: NSEvent) {
        background.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        background.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }
}
