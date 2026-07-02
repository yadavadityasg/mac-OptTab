import Cocoa

struct WindowInfo {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    let title: String

    var appIcon: NSImage? {
        NSRunningApplication(processIdentifier: ownerPID)?.icon
    }
}

/// Enumerates real, on-screen, user-facing windows across all apps —
/// the same building block real window switchers use.
final class WindowManager {
    func listWindows() -> [WindowInfo] {
        guard let infoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: AnyObject]] else {
            return []
        }

        let myPID = ProcessInfo.processInfo.processIdentifier
        var seen = Set<CGWindowID>()
        var windows: [WindowInfo] = []

        for info in infoList {
            // Layer 0 = normal app windows (skips menu bar, dock, overlays)
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID != myPID else { continue }
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID, !seen.contains(windowID) else { continue }
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }

            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0
            if width < 80 || height < 60 { continue } // skip tiny utility/status windows

            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            if alpha <= 0.01 { continue } // skip invisible windows

            let ownerName = (info[kCGWindowOwnerName as String] as? String) ?? "Unknown"
            if ownerName == "Window Server" || ownerName == "Dock" { continue }

            let title = (info[kCGWindowName as String] as? String) ?? ""

            seen.insert(windowID)
            windows.append(WindowInfo(windowID: windowID, ownerPID: ownerPID, ownerName: ownerName, title: title))
        }

        // CGWindowListCopyWindowInfo already returns front-to-back z-order,
        // which gives us "most recently used" ordering for free.
        return windows
    }
}
