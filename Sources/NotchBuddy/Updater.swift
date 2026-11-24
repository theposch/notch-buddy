import Foundation

/// Looks for a newer version on the downloads page, once at launch and then once a day.
/// It only tells the user; downloading and installing is up to them.
/// The page's address comes from the app's Info.plist (NBReleasesURL), set when a release is built.
/// Without one, it never checks.
enum Updater {
    struct Release: Equatable {
        var version: String
        var page: URL
    }

    static var feed: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "NBReleasesURL") as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Checks now and every day after, calling `found` on the main actor.
    @MainActor
    static func watch(found: @escaping @MainActor (Release?) -> Void) -> Task<Void, Never>? {
        guard let feed else { return nil }
        return Task {
            while !Task.isCancelled {
                if let (data, _) = try? await URLSession.shared.data(from: feed) {
                    found(newer(in: data, than: currentVersion))
                }
                try? await Task.sleep(for: .seconds(24 * 60 * 60))
            }
        }
    }

    /// Reads a release page's details ({"tag_name": "v0.4", "html_url": "…"}) and
    /// returns it only if it's newer than ours.
    static func newer(in data: Data, than current: String) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return isNewer(version, than: current) ? Release(version: version, page: page) : nil
    }

    /// "0.10" is newer than "0.9"; "1.2" equals "1.2.0".
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let (p, q) = (i < x.count ? x[i] : 0, i < y.count ? y[i] : 0)
            if p != q { return p > q }
        }
        return false
    }
}
