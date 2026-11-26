import Foundation

/// How full a conversation is, 0–100, like Claude's own context meter.
/// (The same look at the log also gives the model and the conversation's name.)
/// In Terminal, Claude's status line tells us directly. The desktop app has no status line,
/// so the hook helper reads the size of Claude's latest reply from the conversation's log
/// and compares it with the size Claude compacts at.
enum ConversationSize {
    /// Where the helper puts it in an event.
    static let key = "notch_buddy_context"

    /// The event with the conversation's context used, its model and its name added,
    /// as far as the end of its log says.
    static func adding(to event: Data, settings: URL = HookFile().settingsURL) -> Data {
        guard var e = try? JSONSerialization.jsonObject(with: event) as? [String: Any],
              let log = e["transcript_path"] as? String else { return event }
        let lines = tail(ofLog: log)
        if let name = title(in: lines) { e[titleKey] = name }
        // A turn just ended: how Claude's answer began, for the finished row.
        if e["hook_event_name"] as? String == "Stop", let said = lastWords(in: lines) { e[lastKey] = said }
        if let latest = latest(in: lines) {
            let claude = (try? Data(contentsOf: settings)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            e[key] = percent(tokens: latest.tokens, limit: limit(claude ?? [:], model: latest.model, tokens: latest.tokens))
            if let model = latest.model { e[ModelName.key] = model }
        }
        return (try? JSONSerialization.data(withJSONObject: e)) ?? event
    }

    /// The last half megabyte of a conversation's log, newest line first.
    static func tail(ofLog path: String) -> [Data] {
        guard let file = FileHandle(forReadingAtPath: path) else { return [] }
        defer { try? file.close() }
        let size = (try? file.seekToEnd()) ?? 0
        try? file.seek(toOffset: size > 512_000 ? size - 512_000 : 0)
        guard let data = try? file.readToEnd() else { return [] }
        return data.split(separator: UInt8(ascii: "\n")).reversed().map { Data($0) }
    }

    static func latest(inLog path: String) -> (tokens: Int, model: String?)? { latest(in: tail(ofLog: path)) }

    /// The size of Claude's latest reply and the model that wrote it.
    static func latest(in lines: [Data]) -> (tokens: Int, model: String?)? {
        for line in lines {
            guard let e = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  e["type"] as? String == "assistant", e["isSidechain"] as? Bool != true,
                  let message = e["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else { continue }
            let tokens = ["input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens"]
                .reduce(0) { $0 + (usage[$1] as? Int ?? 0) }
            if tokens > 0 { return (tokens, message["model"] as? String) }
        }
        return nil
    }

    /// Where the helper puts the start of Claude's last answer in an event.
    static let lastKey = "notch_buddy_last"

    /// How Claude's latest answer began, in plain words, for a finished row: "Published the page and pushed to main."
    static func lastWords(in lines: [Data]) -> String? {
        for line in lines {
            guard let e = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  e["type"] as? String == "assistant", e["isSidechain"] as? Bool != true,
                  let message = e["message"] as? [String: Any] else { continue }
            let blocks = message["content"] as? [[String: Any]] ?? []
            let text = blocks.last { $0["type"] as? String == "text" }?["text"] as? String ?? message["content"] as? String
            if let said = tidy(text) { return said }
        }
        return nil
    }

    /// One short plain line from an answer: its first words that say something, without Markdown marks.
    static func tidy(_ text: String?, limit: Int = 160) -> String? {
        guard let text else { return nil }
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t#>*-_`|")) }
            .first { $0.contains(where: \.isLetter) }
        guard var said = line else { return nil }
        for mark in ["**", "__", "`"] { said = said.replacingOccurrences(of: mark, with: "") }
        said = said.trimmingCharacters(in: .whitespaces)
        if said.count > limit { said = String(said.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "\u{2026}" }
        return said.isEmpty ? nil : said
    }

    /// Where the helper puts the conversation's name in an event.
    static let titleKey = "notch_buddy_title"

    /// The conversation's name, as the session list shows it ("app build"). Claude writes it
    /// into the log again now and then, so the newest one is near the end.
    static func title(in lines: [Data]) -> String? {
        let marker = Data("\"custom-title\"".utf8)
        for line in lines where line.range(of: marker) != nil {
            if let e = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
               let name = (e["customTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                return name
            }
        }
        return nil
    }

    /// Claude's "auto-compact at" setting for this model (saved per model), or for all models.
    /// With none, 200K; a conversation already bigger than that must have the 1M window.
    static func limit(_ settings: [String: Any], model: String?, tokens: Int) -> Int {
        let perModel = model.flatMap { (settings["modelSettings"] as? [String: Any])?[$0] as? [String: Any] }
        if let set = (perModel?["autoCompactWindow"] ?? settings["autoCompactWindow"]) as? Int, set > 0 { return set }
        return tokens > 200_000 ? 1_000_000 : 200_000
    }

    static func percent(tokens: Int, limit: Int) -> Int {
        min(100, max(0, Int((Double(tokens) / Double(limit) * 100).rounded())))
    }
}
