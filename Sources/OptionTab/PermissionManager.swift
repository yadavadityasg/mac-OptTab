import Cocoa
import ApplicationServices

enum PermissionManager {
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the system's "OptionTab wants to control this computer" prompt.
    static func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [key: true]
        AXIsProcessTrustedWithOptions(options)
    }
}
