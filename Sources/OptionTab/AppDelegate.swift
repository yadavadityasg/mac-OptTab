import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkeyManager = HotkeyManager()
    private let windowManager = WindowManager()
    private let panel = SwitcherPanel()
    private let overviewPanel = OverviewPanel()
    private var currentWindows: [WindowInfo] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon, no Cmd-Tab entry
        setupStatusItem()

        if !PermissionManager.isTrusted() {
            PermissionManager.requestPermission()
        }

        overviewPanel.onSelect = { [weak self] window in
            WindowActivator.activate(window: window)
            self?.hideOverview()
        }
        overviewPanel.onDismiss = { [weak self] in
            self?.hideOverview()
        }

        hotkeyManager.delegate = self
        hotkeyManager.start()
    }

    private func hideOverview() {
        overviewPanel.hidePanel()
        hotkeyManager.isOverlayActive = false
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.stack", accessibilityDescription: "OptionTab")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "OptionTab", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: HotkeyManagerDelegate {
    func hotkeyManagerDidActivate(_ manager: HotkeyManager) {
        hideOverview() // don't let the two overlays overlap
        currentWindows = windowManager.listWindows()
        guard !currentWindows.isEmpty else { return }
        // Default to the second-most-recent window (index 1), like Cmd-Tab does,
        // so a single Option+Tap immediately proposes "the other" window.
        let startIndex = currentWindows.count > 1 ? 1 : 0
        panel.show(windows: currentWindows, selecting: startIndex)
    }

    func hotkeyManagerDidStep(_ manager: HotkeyManager, forward: Bool) {
        panel.select(index: panel.selectedIndex + (forward ? 1 : -1))
    }

    func hotkeyManagerDidDeactivate(_ manager: HotkeyManager) {
        if let window = panel.selectedWindow() {
            WindowActivator.activate(window: window)
        }
        panel.hidePanel()
    }

    func hotkeyManagerDidCancel(_ manager: HotkeyManager) {
        panel.hidePanel()
        hideOverview()
    }

    func hotkeyManagerDidHoldOptionAlone(_ manager: HotkeyManager) {
        if overviewPanel.isVisible {
            return // already showing — let click/Esc/click-away dismiss it
        }
        let windows = windowManager.listWindows()
        guard !windows.isEmpty else { return }
        let activeWindowID = windows.first?.windowID // front-most, since list is z-ordered
        overviewPanel.show(windows: windows, activeWindowID: activeWindowID)
        hotkeyManager.isOverlayActive = true
    }
}
