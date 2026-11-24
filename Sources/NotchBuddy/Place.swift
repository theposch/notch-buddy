import AppKit
import Darwin

/// Where a session lives, so clicking its row can go there.
/// The helper fills this in from what Claude Code passes to hooks.
struct Place: Equatable {
    /// The app Claude runs in (Terminal, Cursor, the Claude app, …).
    var app: String?
    /// In the Claude desktop app: the conversation ("local_…").
    var conversation: String?
    /// The kind of terminal ("Apple_Terminal", "vscode" for Cursor and VS Code, …).
    var terminal: String?
    /// In a terminal: the session's tab ("/dev/ttys003").
    var tty: String?
    /// The project folder.
    var folder: String?

    static let key = "notch_buddy"

    init(app: String? = nil, conversation: String? = nil, terminal: String? = nil, tty: String? = nil, folder: String? = nil) {
        self.app = app
        self.conversation = conversation
        self.terminal = terminal
        self.tty = tty
        self.folder = folder
    }

    /// Read back from an event the helper passed on.
    init(event: [String: Any]) {
        let info = event[Self.key] as? [String: String] ?? [:]
        app = info["app"]
        conversation = info["conversation"]
        terminal = info["terminal"]
        tty = info["tty"]
        folder = event["cwd"] as? String
    }

    // MARK: The helper's side

    /// The event with our own notes about where it came from added.
    static func addingHere(to event: Data, environment: [String: String] = ProcessInfo.processInfo.environment) -> Data {
        guard var e = try? JSONSerialization.jsonObject(with: event) as? [String: Any] else { return event }
        var info: [String: String] = [:]
        info["app"] = environment["__CFBundleIdentifier"]
        if environment["CLAUDE_CODE_ENTRYPOINT"] == "claude-desktop" {
            info["conversation"] = environment["CLAUDE_CODE_HOST_SESSION_ID"]
        }
        info["terminal"] = environment["TERM_PROGRAM"]
        info["tty"] = terminalDevice()
        e[key] = info
        return (try? JSONSerialization.data(withJSONObject: e)) ?? event
    }

    /// The terminal tab of this process or the nearest parent that has one.
    private static func terminalDevice() -> String? {
        var pid = getpid()
        for _ in 0..<6 {
            var info = kinfo_proc()
            var size = MemoryLayout<kinfo_proc>.size
            var query: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
            guard sysctl(&query, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
            let device = info.kp_eproc.e_tdev
            if device != -1, let name = devname(device, S_IFCHR) {
                return "/dev/" + String(cString: name)
            }
            pid = info.kp_eproc.e_ppid
            if pid <= 1 { return nil }
        }
        return nil
    }

    // MARK: The app's side

    /// Brings the session's conversation forward, as closely as we can.
    @MainActor
    func go() {
        if let conversation, let url = URL(string: "claude://claude.ai/epitaxy/\(conversation)") {
            NSWorkspace.shared.open(url)
        } else if terminal == "Apple_Terminal", let tty {
            Self.showTerminalTab(tty)
        } else if terminal == "vscode", let app, let folder,
                  let editor = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) {
            // Cursor and VS Code bring forward the window that already shows this folder.
            NSWorkspace.shared.open([URL(fileURLWithPath: folder)], withApplicationAt: editor,
                                    configuration: NSWorkspace.OpenConfiguration())
        } else if let app {
            NSRunningApplication.runningApplications(withBundleIdentifier: app).first?.activate()
        }
    }

    /// Asks Terminal to bring forward the window and tab with this tty.
    /// The first time, macOS asks whether Notch Buddy may control Terminal.
    private static func showTerminalTab(_ tty: String) {
        let script = """
        on run argv
          tell application "Terminal"
            repeat with w in windows
              repeat with t in tabs of w
                if tty of t is (item 1 of argv) then
                  set selected of t to true
                  set index of w to 1
                  activate
                  return
                end if
              end repeat
            end repeat
            activate
          end tell
        end run
        """
        let osascript = Process()
        osascript.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osascript.arguments = ["-e", script, tty]
        try? osascript.run()
    }
}
