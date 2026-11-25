import Foundation

/// What got done today, for the empty notch: "Today: 5 sessions · 2h 40m of work · 31 files · +412 −96".
/// Kept between launches and started fresh each morning.
struct Today: Codable, Equatable {
    var day: String
    var sessions: Set<String> = []
    var seconds: Double = 0
    var files: Set<String> = []
    var added = 0
    var removed = 0

    static func dayName(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Today's figures, or a fresh start when the saved ones are from another day.
    static func load(_ defaults: UserDefaults = .standard, now: Date = Date()) -> Today {
        let saved = defaults.data(forKey: "today").flatMap { try? JSONDecoder().decode(Today.self, from: $0) }
        return saved?.day == dayName(now) ? saved! : Today(day: dayName(now))
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "today") }
    }

    /// Nil until something happened today.
    var line: String? {
        guard !sessions.isEmpty else { return nil }
        var parts = ["\(sessions.count) session\(sessions.count == 1 ? "" : "s")"]
        let minutes = Int(seconds / 60)
        if minutes > 0 { parts.append((minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m") + " of work") }
        if !files.isEmpty { parts.append("\(files.count) file\(files.count == 1 ? "" : "s") · +\(added) \u{2212}\(removed)") }
        return "Today: " + parts.joined(separator: " · ")
    }
}
