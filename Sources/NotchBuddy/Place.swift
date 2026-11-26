import AppKit
import Darwin

/// Where a session lives, so clicking its row can go there.
/// The helper fills this in from what Claude Code passes to hooks.
struct Place: Equatable {
    /// The app Claude runs in (Terminal, Cursor, the Claude app, …).
    var app: String?
    /// In the Claude desktop app: the conversation ("local_…").
    var conversation: String?
    /// The kind of terminal ("Apple_Terminal", "iTerm.app", "vscode" for Cursor and VS Code, …).
    var terminal: String?
    /// In a terminal: the session's tab ("/dev/ttys003").
    var tty: String?
    /// The project folder.
    var folder: String?
    /// Claude's own process, to tell whether the session is still running.
    var pid: Int32?
    /// JetBrains editors say who they are here ("JetBrains-JediTerm").
    var emulator: String?
    /// In WezTerm: the pane.
    var wezPane: String?
    /// In kitty: the window, and where kitty listens for commands (only set when you've turned that on).
    var kittyWindow: String?
    var kittySocket: String?
    /// In tmux: the pane ("%3") and the server it belongs to.
    var tmuxPane: String?
    var tmuxSocket: String?

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
        pid = info["pid"].flatMap { Int32($0) }
        emulator = info["emulator"]
        wezPane = info["wezPane"]
        kittyWindow = info["kittyWindow"]
        kittySocket = info["kittySocket"]
        tmuxPane = info["tmuxPane"]
        tmuxSocket = info["tmuxSocket"]
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
        info["pid"] = environment["CLAUDE_PID"]
        info["tty"] = terminalDevice()
        info["emulator"] = environment["TERMINAL_EMULATOR"]
        info["wezPane"] = environment["WEZTERM_PANE"]
        info["kittyWindow"] = environment["KITTY_WINDOW_ID"]
        info["kittySocket"] = environment["KITTY_LISTEN_ON"]
        info["tmuxPane"] = environment["TMUX_PANE"]
        // TMUX is "socket path,server pid,session"
        info["tmuxSocket"] = environment["TMUX"]?.split(separator: ",").first.map(String.init)
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

    /// One thing to do to get to a session.
    enum Step: Equatable {
        /// Open an address (the Claude app's conversation).
        case open(URL)
        /// Ask a scriptable terminal to bring a tab forward, by its tty.
        case tab(Scriptable, tty: String)
        /// Run a terminal's own command-line tool (WezTerm, kitty, tmux).
        case run(tool: String, arguments: [String])
        /// Open the project folder with an editor: it brings forward the window that already shows it.
        case openFolder(String, app: String)
        /// Bring an app forward.
        case activate(String)
    }

    /// Terminals that can be asked for a tab by its tty.
    enum Scriptable: String { case terminal = "Terminal", iTerm = "iTerm2" }

    /// How to bring this session's conversation forward, as closely as its app allows:
    /// the exact conversation, tab or pane where the app has a way to ask for it; otherwise the app itself.
    var steps: [Step] {
        if let conversation, let url = URL(string: "claude://claude.ai/epitaxy/\(conversation)") { return [.open(url)] }
        var steps: [Step] = []
        // Inside tmux: its pane first. The terminal around it comes forward below.
        if let tmuxPane {
            let server = tmuxSocket.map { ["-S", $0] } ?? []
            steps.append(.run(tool: "tmux", arguments: server + ["select-window", "-t", tmuxPane]))
            steps.append(.run(tool: "tmux", arguments: server + ["select-pane", "-t", tmuxPane]))
        }
        if terminal == "Apple_Terminal", let tty, tmuxPane == nil {
            return steps + [.tab(.terminal, tty: tty)]
        }
        if terminal == "iTerm.app", let tty, tmuxPane == nil {
            return steps + [.tab(.iTerm, tty: tty)]
        }
        if terminal == "WezTerm", let wezPane {
            steps.append(.run(tool: "wezterm", arguments: ["cli", "activate-pane", "--pane-id", wezPane]))
        }
        // kitty only takes commands when you've switched that on (then it says where it listens).
        if let kittyWindow, let kittySocket {
            steps.append(.run(tool: "kitten", arguments: ["@", "--to", kittySocket, "focus-window", "--match", "id:\(kittyWindow)"]))
        }
        guard let app else { return steps }
        // Editors bring forward the window that already shows this folder. A terminal would open a new one.
        if Self.isEditor(terminal: terminal, emulator: emulator), let folder {
            return steps + [.openFolder(folder, app: app)]
        }
        return steps + [.activate(app)]
    }

    /// Cursor, VS Code and Windsurf call themselves "vscode"; Zed "zed"; JetBrains editors have their own word.
    static func isEditor(terminal: String?, emulator: String?) -> Bool {
        terminal == "vscode" || terminal == "zed" || emulator?.hasPrefix("JetBrains") == true
    }

    /// Brings the session's conversation forward, as closely as we can.
    @MainActor
    func go() {
        for step in steps {
            switch step {
            case .open(let url):
                NSWorkspace.shared.open(url)
            case .tab(let terminal, let tty):
                Self.showTab(in: terminal, tty: tty)
            case .run(let tool, let arguments):
                Self.run(tool, arguments)
            case .openFolder(let folder, let app):
                if let editor = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) {
                    NSWorkspace.shared.open([URL(fileURLWithPath: folder)], withApplicationAt: editor,
                                            configuration: NSWorkspace.OpenConfiguration())
                }
            case .activate(let app):
                NSRunningApplication.runningApplications(withBundleIdentifier: app).first?.activate()
            }
        }
    }

    /// The script that asks a terminal to bring forward the tab with a tty (handed over as its first argument).
    /// The first time, macOS asks whether Notch Buddy may control that app.
    static func tabScript(for terminal: Scriptable) -> String {
        switch terminal {
        case .terminal:
            return """
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
        case .iTerm:
            // iTerm2: windows hold tabs, tabs hold sessions (split panes), and each session knows its tty.
            return """
            on run argv
              tell application "iTerm2"
                repeat with w in windows
                  repeat with t in tabs of w
                    repeat with s in sessions of t
                      if tty of s is (item 1 of argv) then
                        tell s to select
                        tell t to select
                        tell w to select
                        activate
                        return
                      end if
                    end repeat
                  end repeat
                end repeat
                activate
              end tell
            end run
            """
        }
    }

    private static func showTab(in terminal: Scriptable, tty: String) {
        let osascript = Process()
        osascript.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osascript.arguments = ["-e", tabScript(for: terminal), tty]
        try? osascript.run()
    }

    /// Where a terminal's command-line tool is, if it's installed.
    static func find(_ tool: String, isExecutable: (String) -> Bool = FileManager.default.isExecutableFile) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let places = ["/opt/homebrew/bin", "/usr/local/bin", home + "/.local/bin", "/usr/bin",
                      "/Applications/WezTerm.app/Contents/MacOS", "/Applications/kitty.app/Contents/MacOS"]
        return places.map { $0 + "/" + tool }.first(where: isExecutable)
    }

    private static func run(_ tool: String, _ arguments: [String]) {
        guard let path = find(tool) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}
