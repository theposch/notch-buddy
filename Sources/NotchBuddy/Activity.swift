import Foundation

/// What Claude is doing right now, in a few plain words: "Editing NotchView.swift",
/// "Searching the web for swift springs". Made from the tool Claude is about to use.
enum Activity {
    static func line(tool: String, input: [String: Any]) -> String {
        func text(_ key: String) -> String {
            (input[key] as? String ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        }
        func file() -> String {
            URL(fileURLWithPath: input["file_path"] as? String ?? input["notebook_path"] as? String ?? "").lastPathComponent
        }
        switch tool {
        case "Bash":
            // Claude usually says what a command is for; that reads better than the command.
            let said = text("description")
            return said.isEmpty ? "Running \(text("command"))" : said
        case "Edit", "MultiEdit", "NotebookEdit": return "Editing \(file())"
        case "Write": return "Writing \(file())"
        case "Read": return "Reading \(file())"
        case "Grep": return "Searching for \u{201C}\(text("pattern"))\u{201D}"
        case "Glob": return "Looking for files"
        case "WebFetch": return "Reading \(URL(string: text("url"))?.host() ?? "a web page")"
        case "WebSearch": return "Searching the web for \(text("query"))"
        case "Task", "Agent":
            let job = text("description")
            return job.isEmpty ? "Sending out a helper" : "Helper: \(job)"
        case "TodoWrite": return "Updating the to-do list"
        case "Skill": return "Using the \(text("skill")) skill"
        case "ExitPlanMode": return "Writing a plan"
        default:
            // Connected tools are called "mcp__server__tool_name"; "tool name" is the readable part.
            let name = tool.hasPrefix("mcp__") ? (tool.components(separatedBy: "__").last ?? tool) : tool
            return "Using \(name.replacingOccurrences(of: "_", with: " "))"
        }
    }
}

/// Claude's model, short and readable: "claude-opus-5-5" → "Opus 5.5".
enum ModelName {
    /// Where the hook helper puts the model in an event.
    static let key = "notch_buddy_model"

    static func short(_ id: String) -> String? {
        // Drop extras like "[1m]", then look at the pieces between dashes.
        let parts = id.lowercased().replacing(/\[.*?\]/, with: "").split(separator: "-").filter { $0 != "claude" }
        guard let family = parts.first(where: { $0.allSatisfy(\.isLetter) }) else { return nil }
        // Version numbers are short; a long number is a release date.
        let version = parts.filter { $0.count <= 2 && $0.allSatisfy(\.isNumber) }.prefix(2).joined(separator: ".")
        return family.capitalized + (version.isEmpty ? "" : " " + version)
    }
}
