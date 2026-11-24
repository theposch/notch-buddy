import AppKit

// Claude Code runs this same program with "hook" for events and "statusline" for its status line.
switch CommandLine.arguments.dropFirst().first {
case "hook": HookHelper.run()
case "statusline": StatusLine.run(previous: CommandLine.arguments.dropFirst(2).first)
default: break
}

// Otherwise Notch Buddy lives in the notch only: no Dock icon, no app menu.
Prefs.register()
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notch: NotchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // If Claude's settings have our entries from an older version or another place, update them.
        try? HookFile().refresh(command: HookSettings.command(for: Bundle.main.executablePath ?? ""))
        notch = NotchController()
    }
}
