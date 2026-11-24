import AppKit

// Claude Code runs this same program with "hook": pass the event on and quit.
if CommandLine.arguments.dropFirst().first == "hook" {
    HookHelper.run()
}

// Otherwise Notch Buddy lives in the notch only: no Dock icon, no app menu.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notch: NotchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        notch = NotchController()
    }
}
