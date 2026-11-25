import Foundation
import Observation
import os

/// Usage without the Terminal: asks Anthropic how much of an account's 5-hour and weekly limits
/// is used, with a login already on this Mac. This is how other usage apps do it too. It isn't an
/// official feature, so it can stop working; the Terminal status line stays as a backup.
/// Logins are only kept in memory and only ever sent to Anthropic.
@MainActor @Observable
final class LoginUsage {
    /// Which login: Claude Code's in the Terminal, or the Claude desktop app's own.
    enum Source: String, CaseIterable {
        case terminal, desktop

        var setting: String { self == .terminal ? "loginUsage" : "desktopUsage" }
        var on: Bool { UserDefaults.standard.bool(forKey: setting) }
        var title: String { self == .terminal ? "Terminal login" : "Desktop app" }
        var whose: String { self == .terminal ? "Claude Code\u{2019}s login" : "The desktop app\u{2019}s login" }
    }

    enum State: Equatable {
        case off
        /// macOS wants you to OK reading the login (you click Allow in Settings).
        case needsOK
        case checked(Date)
        case problem(String)
    }

    /// What each check did, for Console (never the login itself).
    nonisolated static let log = Logger(subsystem: "local.notchbuddy", category: "usage")

    let source: Source
    private(set) var state: State = .off {
        didSet { if state != oldValue { Self.log.notice("\(self.source.rawValue, privacy: .public) check: \(String(describing: self.state), privacy: .public)") } }
    }
    /// Gets the usage, in the same shape the status line sends it, with the account's organization.
    @ObservationIgnored var onUsage: (([String: Any]) -> Void)?
    @ObservationIgnored private var login: (secret: String, org: String?)?
    @ObservationIgnored private var lastTry = Date.distantPast
    @ObservationIgnored private var waitUntil = Date.distantPast
    @ObservationIgnored private var loop: Task<Void, Never>?

    init(_ source: Source) {
        self.source = source
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.check()
                try? await Task.sleep(for: .seconds(120))
            }
        }
    }

    /// Checks now if it's on and hasn't checked in the last 20 seconds (a turn just ended, say).
    /// `asking`: you clicked something, so macOS may show its Keychain prompt.
    func check(asking: Bool = false) async {
        guard source.on else { state = .off; login = nil; return }
        guard asking || (Date() >= waitUntil && Date().timeIntervalSince(lastTry) >= 20) else { return }
        lastTry = Date()

        if login == nil {
            // Off the main thread: macOS's prompt waits for you, and the notch shouldn't.
            switch source {
            case .terminal:
                switch await Task.detached(operation: { Self.readTerminalLogin(asking: asking) }).value {
                case .found(let token): login = (token, Account.terminalOrg())
                case .needsOK: state = .needsOK; return
                case .missing: state = .problem("Log in to Claude Code first."); return
                case .expired: state = .problem("Waiting for Claude Code to renew its login."); return
                }
            case .desktop:
                switch await Task.detached(operation: { DesktopLogin.read(asking: asking) }).value {
                case .found(let session, let org): login = (session, org)
                case .needsOK: state = .needsOK; return
                case .missing: state = .problem("Log in to the Claude desktop app first."); return
                }
            }
        }
        guard let login, let request = request(login) else { return }

        guard let (data, response) = try? await Self.session.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else {
            state = .problem("Couldn\u{2019}t reach Anthropic.")
            return
        }
        let text = String(decoding: data.prefix(300), as: UTF8.self)
        let name = source.rawValue
        switch status {
        case 200:
            guard var usage = Self.event(from: data) else {
                Self.log.notice("\(name, privacy: .public) answer not understood: \(text, privacy: .private)")
                state = .problem("Anthropic\u{2019}s answer changed.")
                return
            }
            Self.log.notice("\(name, privacy: .public) usage: 5 hours \(String(describing: usage["used_percentage"] ?? "none"), privacy: .public)%, week \(String(describing: usage["week_used"] ?? "none"), privacy: .public)%")
            if let org = login.org { usage[Account.key] = org }
            usage["from"] = source.title
            onUsage?(usage)
            state = .checked(Date())
        case 401, 403:
            Self.log.notice("\(name, privacy: .public) answer \(status): \(text, privacy: .private)")
            self.login = nil   // renewed or logged out: read it again next time
            state = .problem("\(source.whose) has changed. Trying again soon.")
        case 429:
            waitUntil = Date().addingTimeInterval(600)
            state = .problem("Asked too often. Trying again in 10 minutes.")
        default:
            Self.log.notice("\(name, privacy: .public) answer \(status): \(text, privacy: .private)")
            state = .problem("Anthropic said no (\(status)).")
        }
    }

    /// No cookie jar, no cache, no redirects: nothing is written to disk, and the login only
    /// ever goes to the address below.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        return URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }()

    private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest) async -> URLRequest? { nil }
    }

    /// Claude Code's login asks the API; the desktop app's asks claude.ai, as the app itself does.
    private func request(_ login: (secret: String, org: String?)) -> URLRequest? {
        var request: URLRequest
        switch source {
        case .terminal:
            request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!, timeoutInterval: 15)
            request.setValue("Bearer \(login.secret)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        case .desktop:
            guard let org = login.org, let url = URL(string: "https://claude.ai/api/organizations/\(org)/usage") else { return nil }
            request = URLRequest(url: url, timeoutInterval: 15)
            request.setValue("sessionKey=\(login.secret)", forHTTPHeaderField: "Cookie")
        }
        request.setValue("NotchBuddy", forHTTPHeaderField: "User-Agent")
        return request
    }

    // MARK: Reading the answer

    /// {"five_hour": {"utilization": 22.0, "resets_at": "2026-11-25T20:00:00Z"}, "seven_day": {…}}
    /// becomes the status line's event: used_percentage, resets_at, week_used, week_resets.
    static func event(from data: Data) -> [String: Any]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var event: [String: Any] = ["hook_event_name": Usage.event]
        if let (used, resets) = window(json["five_hour"], length: 5 * 3600) {
            event["used_percentage"] = used
            event["resets_at"] = resets
        }
        if let (used, resets) = window(json["seven_day"], length: 7 * 86400) {
            event["week_used"] = used
            event["week_resets"] = resets
        }
        return event.count > 1 ? event : nil
    }

    /// A window with no reset time hasn't started yet (nothing used since the last one ended):
    /// it would end `length` after your next message.
    private static func window(_ value: Any?, length: TimeInterval) -> (Double, Double)? {
        guard let window = value as? [String: Any],
              let used = (window["utilization"] as? NSNumber)?.doubleValue else { return nil }
        let resets = (window["resets_at"] as? String).flatMap(date) ?? Date().addingTimeInterval(length)
        return (used, resets.timeIntervalSince1970)
    }

    static func date(_ text: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: text)
    }

    // MARK: Claude Code's login

    enum Login: Equatable, Sendable { case found(String), needsOK, missing, expired }

    nonisolated private static func readTerminalLogin(asking: Bool) -> Login {
        switch Keychain.read("Claude Code-credentials", asking: asking) {
        case .found(let data): token(from: data)
        case .needsOK: .needsOK
        case .missing: .missing
        }
    }

    /// {"claudeAiOauth": {"accessToken": "…", "expiresAt": 1764100000000, …}}
    nonisolated static func token(from data: Data, now: Date = Date()) -> Login {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let login = json["claudeAiOauth"] as? [String: Any],
              let token = login["accessToken"] as? String, !token.isEmpty else { return .missing }
        if let expires = (login["expiresAt"] as? NSNumber)?.doubleValue, expires / 1000 < now.timeIntervalSince1970 {
            return .expired
        }
        return .found(token)
    }
}
