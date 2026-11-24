import Foundation

/// Claude Code's permission requests: which ones we answer, the one-line summary
/// a row shows, and the answer printed back to Claude.
enum Permission {
    /// How long the helper waits for Allow or Deny. Meanwhile Claude also asks in the
    /// terminal or app as usual, so answering there works too.
    static let wait: Double = 60 * 60
    /// Claude's own time limit for our hook: a little longer, so we always give up first.
    static let hookTimeout = Int(wait) + 30

    /// Questions with options are answered in the conversation, not with Allow / Deny.
    static let questionTool = "AskUserQuestion"

    /// True for a permission request the helper should wait on.
    static func wantsAnswer(_ event: Data) -> Bool {
        guard let e = try? JSONSerialization.jsonObject(with: event) as? [String: Any] else { return false }
        return e["hook_event_name"] as? String == "PermissionRequest" && e["tool_name"] as? String != questionTool
    }

    /// What the helper prints for the app's answer ("allow" or "deny"). Anything else: nothing.
    static func output(for reply: Data) -> Data? {
        let decision: [String: Any]
        switch String(decoding: reply, as: UTF8.self) {
        case "allow": decision = ["behavior": "allow"]
        case "deny": decision = ["behavior": "deny", "message": "The user denied this from Notch Buddy."]
        default: return nil
        }
        let output = ["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": decision]]
        return try? JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
    }

    /// "Run: npm test", "Edit: README.md", …
    static func summary(tool: String, input: [String: Any]) -> String {
        func file() -> String {
            let path = input["file_path"] as? String ?? input["notebook_path"] as? String ?? input["path"] as? String ?? ""
            return URL(fileURLWithPath: path).lastPathComponent
        }
        let text: (String, String)
        switch tool {
        case "Bash": text = ("Run", input["command"] as? String ?? "")
        case "Edit", "MultiEdit", "NotebookEdit": text = ("Edit", file())
        case "Write": text = ("Write", file())
        case "Read": text = ("Read", file())
        case "WebFetch": text = ("Open", URL(string: input["url"] as? String ?? "")?.host() ?? "")
        case "WebSearch": text = ("Search", input["query"] as? String ?? "")
        case "ExitPlanMode": return "Plan: ready to start"
        case questionTool: return "Has a question"
        default:
            // MCP tools are called "mcp__server__tool"; show just the tool.
            let name = tool.hasPrefix("mcp__") ? (tool.components(separatedBy: "__").last ?? tool) : tool
            return "Use: \(name)"
        }
        let detail = text.1.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return detail.isEmpty ? text.0 : "\(text.0): \(detail.trimmingCharacters(in: .whitespaces))"
    }
}
