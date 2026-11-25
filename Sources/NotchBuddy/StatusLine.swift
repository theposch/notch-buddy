import Foundation

/// Claude Code only shares usage with its status line, so Connect puts us in front of it.
/// Each time Claude draws the status line, we pass the usage to the app, then show the
/// earlier status line exactly as it was (or a short line of our own when there was none).
enum StatusLine {
    static func run(previous: String?) -> Never {
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { exit(0) }   // safety net
        let input = FileHandle.standardInput.readDataToEndOfFile()
        if let usage = event(from: input) {
            _ = HookHelper.send(usage, to: EventSocket.path, wait: nil)
        }
        if let previous = previous.flatMap(HookSettings.unpack),
           let command = previous["command"] as? String {
            exit(passThrough(command, input: input))
        }
        if let line = ownLine(from: input) { print(line) }
        exit(0)
    }

    /// The 5-hour and weekly usage, and this conversation's context used and cost, as an event
    /// for the app. Nil when Claude included none of them.
    static func event(from input: Data) -> Data? {
        guard let json = try? JSONSerialization.jsonObject(with: input) as? [String: Any] else { return nil }
        var event: [String: Any] = ["hook_event_name": Usage.event]
        if let window = (json["rate_limits"] as? [String: Any])?["five_hour"] as? [String: Any],
           let used = window["used_percentage"] as? Double, let resets = window["resets_at"] as? Double {
            event["used_percentage"] = used
            event["resets_at"] = resets
        }
        if let window = (json["rate_limits"] as? [String: Any])?["seven_day"] as? [String: Any],
           let used = window["used_percentage"] as? Double, let resets = window["resets_at"] as? Double {
            event["week_used"] = used
            event["week_resets"] = resets
        }
        if let id = json["session_id"] as? String {
            if let context = (json["context_window"] as? [String: Any])?["used_percentage"] as? Double {
                event["context_used"] = context
            }
            if let cost = (json["cost"] as? [String: Any])?["total_cost_usd"] as? Double { event["cost"] = cost }
            if event["context_used"] != nil || event["cost"] != nil { event["session_id"] = id }
        }
        guard event.count > 1 else { return nil }
        return try? JSONSerialization.data(withJSONObject: event)
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
struct Usage: Codable, Equatable {
    static let event = "NotchBuddyUsage"
    var used: Double
    var resets: Date

    /// Whole percent left, or nil once the window has reset and we don't know yet.
    func left(at now: Date = Date()) -> Int? {
        now < resets ? max(0, Int((100 - used).rounded())) : nil
    }
}
