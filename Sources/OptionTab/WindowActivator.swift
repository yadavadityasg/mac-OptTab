import Cocoa
import ApplicationServices

// Private but widely-used API (also relied on by several open-source switchers)
// that maps an AXUIElement window to its CGWindowID. There is no public API for this.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: inout CGWindowID) -> AXError

enum WindowActivator {
    static func activate(window: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else { return }
        app.activate(options: [.activateIgnoringOtherApps])

        let axApp = AXUIElementCreateApplication(window.ownerPID)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let axWindows = windowsRef as? [AXUIElement] else {
            return
        }

        for axWindow in axWindows {
            var wid: CGWindowID = 0
            if _AXUIElementGetWindow(axWindow, &wid) == .success, wid == window.windowID {
                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, axWindow)
                break
            }
        }
    }
}
