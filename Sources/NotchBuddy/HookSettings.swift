import Foundation

/// Our entries in Claude Code's settings: one hook per event, and our status line in front of
/// whatever status line was there (kept inside our command, so Disconnect can put it back).
/// Everything else in the file is left alone, including other apps' hooks.
enum HookSettings {
    static let events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest", "PostToolUse",
                         "PostToolUseFailure", "SubagentStart", "SubagentStop", "Notification", "Stop", "StopFailure", "PreCompact", "SessionEnd"]
    /// Every command we add ends like this, which is how we find ours again.
    static let ending = "/Contents/MacOS/NotchBuddy' hook"

    static func command(for program: String) -> String {
        "'" + program.replacingOccurrences(of: "'", with: "'\\''") + "' hook"
    }

    static func isOurs(_ hook: Any) -> Bool {
        ((hook as? [String: Any])?["command"] as? String)?.hasSuffix(ending) ?? false
    }

    // MARK: Status line

    static let statusWord = " statusline"

    /// Our status line command: the app, then the earlier status line setting packed as base64.
    static func statusCommand(hook: String, previous: [String: Any]?) -> String {
        var command = String(hook.dropLast(" hook".count)) + statusWord
        if let previous, let data = try? JSONSerialization.data(withJSONObject: previous, options: [.sortedKeys]) {
            command += " " + data.base64EncodedString()
        }
        return command
    }

    /// The part of our status line command before the packed setting.
    static func ourStatusPrefix(_ settings: [String: Any]) -> String? {
        guard let command = (settings["statusLine"] as? [String: Any])?["command"] as? String,
              let range = command.range(of: "/Contents/MacOS/NotchBuddy'" + statusWord) else { return nil }
        return String(command[..<range.upperBound])
    }

    /// The status line setting we stood in front of, read back from our command.
    static func previousStatusLine(_ command: String) -> [String: Any]? {
        guard let packed = command.components(separatedBy: statusWord + " ").last, packed != command else { return nil }
        return unpack(packed)
    }

    static func unpack(_ packed: String) -> [String: Any]? {
        guard let data = Data(base64Encoded: packed) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func contains(_ settings: [String: Any]) -> Bool {
        removing(from: settings).changed
    }

    /// True when our entries are there but differ from what this version would write
    /// (an older version, or the app has moved).
    static func isOutdated(_ settings: [String: Any], command: String) -> Bool {
        contains(settings) && ours(in: settings) != ours(in: adding(to: [:], command: command))
    }

    /// Our entries only, as "event command timeout" lines.
    static func ours(in settings: [String: Any]) -> Set<String> {
        var found = Set<String>()
        if let status = ourStatusPrefix(settings) { found.insert("statusLine \(status)") }
        for (event, groups) in settings["hooks"] as? [String: Any] ?? [:] {
            for group in groups as? [[String: Any]] ?? [] {
                for hook in group["hooks"] as? [[String: Any]] ?? [] where isOurs(hook) {
                    found.insert("\(event) \(hook["command"] ?? "") \(hook["timeout"] ?? "")")
                }
            }
        }
        return found
    }

    /// The settings with our entries taken out, and whether there were any.
    static func removing(from settings: [String: Any]) -> (settings: [String: Any], changed: Bool) {
        var result = settings
        var changed = false
        if ourStatusPrefix(settings) != nil {
            let command = (settings["statusLine"] as? [String: Any])?["command"] as? String ?? ""
            result["statusLine"] = previousStatusLine(command)
            changed = true
        }
        guard var hooks = settings["hooks"] as? [String: Any] else { return (result, changed) }
        for (event, value) in hooks {
            guard let groups = value as? [Any] else { continue }
            var touched = false
            let kept: [Any] = groups.compactMap { item in
                guard var group = item as? [String: Any], let list = group["hooks"] as? [Any] else { return item }
                let rest = list.filter { !isOurs($0) }
                if rest.count == list.count { return item }
                touched = true
                if rest.isEmpty { return nil }
                group["hooks"] = rest
                return group
            }
            if touched {
                changed = true
                hooks[event] = kept.isEmpty ? nil : kept
            }
        }
        guard changed else { return (settings, false) }
        result["hooks"] = hooks.isEmpty ? nil : hooks
        return (result, true)
    }

    /// The settings with exactly one of our entries for each event.
    static func adding(to settings: [String: Any], command: String) -> [String: Any] {
        var result = removing(from: settings).settings
        var hooks = result["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var groups = hooks[event] as? [Any] ?? []
            // Only a permission request waits for an answer; everything else is over in a moment.
            let timeout = event == "PermissionRequest" ? Permission.hookTimeout : 5
            groups.append(["hooks": [["type": "command", "command": command, "timeout": timeout]]])
            hooks[event] = groups
        }
        result["hooks"] = hooks
        // Stand in front of the status line, keeping its other options (like padding).
        let previous = result["statusLine"] as? [String: Any]
        var status = previous ?? ["type": "command"]
        status["command"] = statusCommand(hook: command, previous: previous)
        result["statusLine"] = status
        return result
    }
}

/// Reads and writes the real file, keeping a backup so Remove can put it back exactly.
struct HookFile {
    var settingsURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/settings.json")
    var folder = EventSocket.folder

    private var file: URL { settingsURL.resolvingSymlinksInPath() }
    private var backupURL: URL { folder.appending(path: "settings-backup.json") }
    /// A copy of what we last wrote. If the file still matches it, Remove restores the backup.
    private var writtenURL: URL { folder.appending(path: "settings-written.json") }

    struct Unreadable: LocalizedError {
        var errorDescription: String? { "Claude's settings file isn't plain JSON, so it was left untouched." }
    }

    func install(command: String) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let current = try? Data(contentsOf: file)
        let settings = try current.map(Self.parse) ?? [:]
        // Back up the file as it was before we ever added ourselves (empty = there was no file).
        if !HookSettings.contains(settings) {
            try (current ?? Data()).write(to: backupURL, options: .atomic)
        }
        let new = try Self.encode(HookSettings.adding(to: settings, command: command), like: current)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try new.write(to: file, options: .atomic)
        try new.write(to: writtenURL, options: .atomic)
    }

    /// True when Claude's settings have our entries.
    var isConnected: Bool {
        (try? Data(contentsOf: file)).flatMap { try? Self.parse($0) }.map(HookSettings.contains) ?? false
    }

    /// Updates our entries if they are there but out of date. Touches nothing else.
    func refresh(command: String) throws {
        guard command.hasSuffix(HookSettings.ending),   // only from the installed app, never a test build
              let current = try? Data(contentsOf: file),
              HookSettings.isOutdated(try Self.parse(current), command: command) else { return }
        try install(command: command)
    }

    func remove() throws {
        defer { try? FileManager.default.removeItem(at: writtenURL) }
        guard let current = try? Data(contentsOf: file) else { return }
        // Nothing changed since we wrote it: put the original back byte for byte.
        if current == (try? Data(contentsOf: writtenURL)), let backup = try? Data(contentsOf: backupURL) {
            if backup.isEmpty { try FileManager.default.removeItem(at: file) }
            else { try backup.write(to: file, options: .atomic) }
            return
        }
        // Otherwise take out only our entries.
        let result = HookSettings.removing(from: try Self.parse(current))
        if result.changed { try Self.encode(result.settings, like: current).write(to: file, options: .atomic) }
    }

    static func parse(_ data: Data) throws -> [String: Any] {
        if data.isEmpty { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Unreadable() }
        return object
    }

    static func encode(_ settings: [String: Any], like original: Data?) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        if original?.last == UInt8(ascii: "\n") || original == nil { data.append(UInt8(ascii: "\n")) }
        return data
    }
}
