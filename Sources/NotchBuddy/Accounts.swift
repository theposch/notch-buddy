import Foundation

/// One Claude account's usage. Accounts are told apart by their organization, which every
/// login and every session in the desktop app carries; "" when we don't know it yet.
struct Account: Codable, Equatable, Identifiable {
    var id: String
    var usage: Usage?
    var week: Usage?
    /// Where it's logged in right now, as far as we know: "Terminal login", "Desktop app".
    var from: String?
    /// The email address it's logged in with, when Claude says. Only kept on this Mac.
    var email: String?

    var left: Int? { usage?.left() }

    /// "5 hours: 72% left, resets 3:50 PM · Week: 88% left", for hovering.
    var summary: String {
        var parts: [String] = email.map { [$0] } ?? []
        if let usage, let left { parts.append("5 hours: \(left)% left, resets \(usage.resets.formatted(date: .omitted, time: .shortened))") }
        if let week, let left = week.left() { parts.append("Week: \(left)% left") }
        return parts.joined(separator: " · ")
    }

    // MARK: Your names and colours for it

    static let colors = ["#D97757", "#7FB3E0", "#B48AE0", "#8FBF6A"]

    /// What `from` says for an account that both the Terminal and the desktop app are logged in to.
    static let both = "Terminal and desktop app"

    /// A short name from where it's logged in: "Terminal", "Desktop". "Claude" when that's both or unknown.
    var defaultName: String {
        from == Self.both ? "Claude" : from?.components(separatedBy: " ").first ?? "Claude"
    }

    /// Your name for it, else the short one.
    var name: String {
        UserDefaults.standard.string(forKey: "account.\(id).name") ?? defaultName
    }

    func color(among all: [Account]) -> String {
        UserDefaults.standard.string(forKey: "account.\(id).color")
            ?? Self.colors[(all.firstIndex { $0.id == id } ?? 0) % Self.colors.count]
    }

    /// Switched off in Settings: not shown and not followed.
    var shown: Bool { !UserDefaults.standard.bool(forKey: "account.\(id).hidden") }

    // MARK: Kept between launches

    static func load() -> [Account] {
        UserDefaults.standard.data(forKey: "accounts").flatMap { try? JSONDecoder().decode([Account].self, from: $0) } ?? []
    }

    static func save(_ accounts: [Account]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(accounts), forKey: "accounts")
    }

    // MARK: Which account a session is on

    /// Where the hook helper puts the session's organization in an event.
    static let key = "notch_buddy_org"
    /// And the email address that account is logged in with.
    static let emailKey = "notch_buddy_email"

    /// The desktop app tells each session which organization it runs on. Terminal sessions
    /// don't; they're on the Terminal login's account.
    static func addingOrg(to event: Data, environment: [String: String] = ProcessInfo.processInfo.environment) -> Data {
        guard let org = environment["CLAUDE_CODE_ORGANIZATION_UUID"], !org.isEmpty,
              var e = try? JSONSerialization.jsonObject(with: event) as? [String: Any] else { return event }
        e[key] = org
        if let email = environment["CLAUDE_CODE_USER_EMAIL"], !email.isEmpty { e[emailKey] = email }
        return (try? JSONSerialization.data(withJSONObject: e)) ?? event
    }

    /// The organization Claude Code in the Terminal is logged in to, from its own settings file.
    static func terminalOrg(file: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude.json")) -> String? {
        terminalLogin(file: file)?.org
    }

    /// That organization, and the email address of the login.
    static func terminalLogin(file: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude.json")) -> (org: String, email: String?)? {
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let login = json["oauthAccount"] as? [String: Any],
              let org = login["organizationUuid"] as? String else { return nil }
        return (org, login["emailAddress"] as? String)
    }
}

/// Which account's usage the closed notch shows when there are several.
enum Follow: Equatable {
    /// The account of the session you last worked in.
    case lead
    /// Whichever is closest to running out.
    case lowest
    /// Always this account.
    case account(String)

    static var saved: Follow {
        get {
            switch UserDefaults.standard.string(forKey: "usageFollows") ?? "lead" {
            case "lead": .lead
            case "lowest": .lowest
            case let id: .account(id)
            }
        }
        set {
            let text = switch newValue { case .lead: "lead"; case .lowest: "lowest"; case .account(let id): id }
            UserDefaults.standard.set(text, forKey: "usageFollows")
        }
    }
}
