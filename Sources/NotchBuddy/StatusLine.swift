import Foundation

/// Claude Code only shares usage with its status line, so Connect puts us in front of it.
/// Each time Claude draws the status line, we pass the usage to the app, then show the
/// earlier status line exactly as it was (or a short line of our own when there was none).
enum StatusLine {
    static func run(previous: String?) -> Never {
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { exit(0) }   // safety net
        let input = FileHandle.standardInput.readDataToEndOfFile()
        if let usage = usageEvent(from: input) {
            _ = HookHelper.send(usage, to: EventSocket.path, wait: nil)
        }
        if let previous = previous.flatMap(HookSettings.unpack),
           let command = previous["command"] as? String {
            exit(passThrough(command, input: input))
        }
        if let line = ownLine(from: input) { print(line) }
        exit(0)
    }

    /// The 5-hour usage, as an event for the app. Nil when Claude didn't include it.
    static func usageEvent(from input: Data) -> Data? {
        guard let json = try? JSONSerialization.jsonObject(with: input) as? [String: Any],
              let window = (json["rate_limits"] as? [String: Any])?["five_hour"] as? [String: Any],
              let used = window["used_percentage"] as? Double,
              let resets = window["resets_at"] as? Double else { return nil }
        return try? JSONSerialization.data(withJSONObject: [
            "hook_event_name": Usage.event, "used_percentage": used, "resets_at": resets,
        ])
    }

    /// "Opus · 12% context"
    static func ownLine(from input: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: input) as? [String: Any] else { return nil }
        var parts: [String] = []
        if let model = (json["model"] as? [String: Any])?["display_name"] as? String { parts.append(model) }
        if let used = (json["context_window"] as? [String: Any])?["used_percentage"] as? Double {
            parts.append("\(Int(used.rounded()))% context")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Runs the earlier status line with the same input; its output goes straight to Claude.
    private static func passThrough(_ command: String, input: Data) -> Int32 {
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", command]
        let pipe = Pipe()
        shell.standardInput = pipe
        do { try shell.run() } catch { return 1 }
        pipe.fileHandleForWriting.write(input)
        try? pipe.fileHandleForWriting.close()
        shell.waitUntilExit()
        return shell.terminationStatus
    }
}

/// Usage left in the 5-hour window, as the app keeps it.
struct Usage: Equatable {
    static let event = "NotchBuddyUsage"
    var used: Double
    var resets: Date

    /// Whole percent left, or nil once the window has reset and we don't know yet.
    func left(at now: Date = Date()) -> Int? {
        now < resets ? max(0, Int((100 - used).rounded())) : nil
    }

    // Kept between launches.
    static func load() -> Usage? {
        let d = UserDefaults.standard
        guard d.object(forKey: "usageUsed") != nil else { return nil }
        return Usage(used: d.double(forKey: "usageUsed"), resets: Date(timeIntervalSince1970: d.double(forKey: "usageResets")))
    }

    func save() {
        UserDefaults.standard.set(used, forKey: "usageUsed")
        UserDefaults.standard.set(resets.timeIntervalSince1970, forKey: "usageResets")
    }
}
