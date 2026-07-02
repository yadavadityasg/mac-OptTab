import Cocoa

protocol HotkeyManagerDelegate: AnyObject {
    /// First Tab press while Control+Option are held — switcher should appear.
    func hotkeyManagerDidActivate(_ manager: HotkeyManager)
    /// Subsequent Tab presses while Control+Option stay held — move the selection.
    func hotkeyManagerDidStep(_ manager: HotkeyManager, forward: Bool)
    /// Control or Option was released while switcher was active — commit the selection.
    func hotkeyManagerDidDeactivate(_ manager: HotkeyManager)
    /// Esc was pressed while an overlay was active — abort, no switch.
    func hotkeyManagerDidCancel(_ manager: HotkeyManager)
    /// Control+Option have been held together (no Tab, no other key) past the hold
    /// threshold. Show the overview — it stays open even after the keys are released.
    func hotkeyManagerDidHoldOptionAlone(_ manager: HotkeyManager)
}

/// Listens globally for Control+Option (+ Tab) using a CGEventTap.
/// Uses Control+Option instead of bare Option so it doesn't collide with
/// macOS's own "hold Option" Siri shortcut on Macs that have it configured that way.
/// Requires Accessibility permission (System Settings > Privacy & Security > Accessibility).
final class HotkeyManager {
    weak var delegate: HotkeyManagerDelegate?

    /// Set by AppDelegate whenever a non-switcher overlay (e.g. the overview grid)
    /// is showing, so Esc can dismiss it too.
    var isOverlayActive = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isSwitcherActive = false
    private var controlKeyDown = false
    private var optionKeyDown = false
    private var anyOtherKeyPressedDuringHold = false
    private var pendingHoldWorkItem: DispatchWorkItem?

    /// True only when both Control and Option are held together.
    private var comboActive: Bool { controlKeyDown && optionKeyDown }

    /// How long Control+Option must be held together before the overview appears.
    private let holdThreshold: TimeInterval = 0.35

    // Standard ANSI virtual keycodes
    private let tabKeyCode: CGKeyCode = 48
    private let escKeyCode: CGKeyCode = 53

    func start() {
        let eventMask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: selfPointer
        ) else {
            print("⚠️ Failed to create event tap. Is Accessibility permission granted to this app?")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("✅ Event tap created and enabled.")
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS can disable a tap under load; re-enable immediately.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }

        if type == .flagsChanged {
            let controlPressed = event.flags.contains(.maskControl)
            let optionPressed = event.flags.contains(.maskAlternate)
            let wasComboActive = comboActive

            controlKeyDown = controlPressed
            optionKeyDown = optionPressed

            let isComboActiveNow = comboActive

            if isComboActiveNow && !wasComboActive {
                print("🔵 Control+Option combo ENGAGED — hold timer started (\(holdThreshold)s)")
                anyOtherKeyPressedDuringHold = false
                scheduleHoldCheck()
            } else if !isComboActiveNow && wasComboActive {
                print("⚪️ Control+Option combo released")
                pendingHoldWorkItem?.cancel()
                pendingHoldWorkItem = nil
                if isSwitcherActive {
                    isSwitcherActive = false
                    notify { $0.hotkeyManagerDidDeactivate(self) }
                }
                // Note: the overview (if any) is triggered by the hold timer below,
                // not by release, so nothing else happens here.
            }
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

            if keyCode == tabKeyCode {
                print("⭾ Tab pressed — comboActive=\(comboActive) (control=\(controlKeyDown), option=\(optionKeyDown))")
            }

            if keyCode == tabKeyCode && comboActive {
                pendingHoldWorkItem?.cancel()
                let goingBackward = event.flags.contains(.maskShift)
                if !isSwitcherActive {
                    isSwitcherActive = true
                    notify { $0.hotkeyManagerDidActivate(self) }
                } else {
                    notify { $0.hotkeyManagerDidStep(self, forward: !goingBackward) }
                }
                return nil // swallow Tab so it doesn't reach the focused app
            }

            if keyCode == escKeyCode && (isSwitcherActive || isOverlayActive) {
                isSwitcherActive = false
                notify { $0.hotkeyManagerDidCancel(self) }
                return nil
            }

            if comboActive {
                // Any other key while Control+Option are held means this isn't a
                // solo combo hold (app shortcuts that happen to use both, etc.)
                anyOtherKeyPressedDuringHold = true
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func scheduleHoldCheck() {
        pendingHoldWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // Only fire if Control+Option are still held, we didn't enter Tab-cycle
            // mode, and no other key interrupted the hold in the meantime.
            guard self.comboActive, !self.isSwitcherActive, !self.anyOtherKeyPressedDuringHold else {
                print("⏱️ Hold timer fired but guard failed — combo=\(self.comboActive) switcher=\(self.isSwitcherActive) otherKey=\(self.anyOtherKeyPressedDuringHold)")
                return
            }
            print("🟢 Hold threshold reached — showing overview")
            self.notify { $0.hotkeyManagerDidHoldOptionAlone(self) }
        }
        pendingHoldWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: workItem)
    }

    private func notify(_ action: @escaping (HotkeyManagerDelegate) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let delegate = self.delegate else { return }
            action(delegate)
        }
    }
}
