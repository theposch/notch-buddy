import AppKit
import CryptoKit
import Foundation
import Security
import os

/// Looks for a newer version on the downloads page, once at launch and then once a day, and tells
/// the user. Nothing is downloaded until they click Update; then it fetches that version's zip,
/// checks it, puts it where this app is and starts it.
/// The page's address comes from the app's Info.plist (NBReleasesURL), set when a release is built.
/// Without one, it never checks.
enum Updater {
    struct Release: Equatable {
        var version: String
        var page: URL
        /// The zip to install. Nil when the release has none we trust: then Update opens the page.
        var download: URL?
        /// The zip's SHA-256, as the downloads page gives it.
        var digest: String?
    }

    /// What an update did, for Console.
    static let log = Logger(subsystem: "local.notchbuddy", category: "update")

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

    /// Reads a release page's details ({"tag_name": "v0.4", "html_url": "…", "assets": […]}) and
    /// returns it only if it's newer than ours.
    static func newer(in data: Data, than current: String) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard isNewer(version, than: current) else { return nil }
        let zip = (json["assets"] as? [[String: Any]] ?? []).first { ($0["name"] as? String ?? "").hasSuffix(".zip") }
        let download = (zip?["browser_download_url"] as? String).flatMap(URL.init(string:)).flatMap { trusted($0, page: page) ? $0 : nil }
        let digest = (zip?["digest"] as? String).flatMap { $0.hasPrefix("sha256:") ? String($0.dropFirst(7)).lowercased() : nil }
        return Release(version: version, page: page, download: download, digest: download == nil ? nil : digest)
    }

    /// A download counts only from the same site and project as the release page, over https:
    /// "https://github.com/you/notch-buddy/releases/download/…" for ".../you/notch-buddy/releases/tag/…".
    static func trusted(_ download: URL, page: URL) -> Bool {
        let project = page.pathComponents.prefix(3)   // "/", owner, name
        return download.scheme == "https" && page.scheme == "https" && download.host() == page.host()
            && project.count == 3 && Array(download.pathComponents.prefix(3)) == Array(project)
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

    // MARK: Installing

    enum Problem: LocalizedError, Equatable {
        case noDownload, download, changed, unpack, notOurs, signature, place

        var errorDescription: String? {
            switch self {
            case .noDownload: "This version has no download to install."
            case .download: "Couldn\u{2019}t download the update."
            case .changed: "The download doesn\u{2019}t match the one on the downloads page, so it wasn\u{2019}t installed."
            case .unpack: "Couldn\u{2019}t open the download."
            case .notOurs: "The download isn\u{2019}t the Notch Buddy version it says it is, so it wasn\u{2019}t installed."
            case .signature: "The download is damaged or signed by someone else, so it wasn\u{2019}t installed."
            case .place: "Notch Buddy can\u{2019}t replace itself where it is. Move it to your Applications folder first."
            }
        }
    }

    /// Downloads a release, checks it, swaps it in for this app and starts it.
    /// When it works the app quits, so this only comes back by throwing.
    @MainActor
    static func install(_ release: Release) async throws {
        guard let url = release.download else { throw Problem.noDownload }
        let app = Bundle.main.bundleURL
        guard canReplace(app) else { throw Problem.place }
        // A scratch folder on the same disk as the app, so the swap is one step.
        guard let folder = try? FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                         appropriateFor: app, create: true) else { throw Problem.place }
        defer { try? FileManager.default.removeItem(at: folder) }

        let zip = folder.appending(path: "update.zip")
        guard let (file, response) = try? await URLSession.shared.download(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              (try? FileManager.default.moveItem(at: file, to: zip)) != nil else { throw Problem.download }

        let new = try await Task.detached { try unpack(zip, in: folder, release: release, replacing: app) }.value
        try swap(new, into: app)
        relaunch(app)
    }

    /// False where an app can't be swapped: macOS runs a freshly downloaded app from a hidden
    /// read-only copy until it's moved, and some folders aren't ours to write in.
    static func canReplace(_ app: URL) -> Bool {
        !app.path.contains("/AppTranslocation/") && app.pathExtension == "app"
            && FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path)
    }

    /// Checks the zip against the downloads page's fingerprint, unpacks it, and makes sure what's
    /// inside is this app, the promised version, and properly signed. Returns the new app.
    static func unpack(_ zip: URL, in folder: URL, release: Release, replacing app: URL) throws -> URL {
        if let digest = release.digest {
            guard let data = try? Data(contentsOf: zip, options: .mappedIfSafe), sha256(data) == digest else { throw Problem.changed }
        }
        let unpacked = folder.appending(path: "unpacked")
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, unpacked.path]
        ditto.standardOutput = FileHandle.nullDevice
        ditto.standardError = FileHandle.nullDevice
        guard (try? ditto.run()) != nil else { throw Problem.unpack }
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0,
              let new = (try? FileManager.default.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil))?
                .first(where: { $0.pathExtension == "app" }) else { throw Problem.unpack }

        guard let ours = info(app)?["CFBundleIdentifier"] as? String, let theirs = info(new),
              theirs["CFBundleIdentifier"] as? String == ours,
              theirs["CFBundleShortVersionString"] as? String == release.version else { throw Problem.notOurs }
        guard signedLike(app, new) else { throw Problem.signature }
        return new
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func info(_ app: URL) -> [String: Any]? {
        (try? Data(contentsOf: app.appending(path: "Contents/Info.plist")))
            .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
    }

    /// The new app's signature must be intact. When this app is signed by a developer team
    /// (a Developer ID release), the new one must be signed by the same team.
    static func signedLike(_ current: URL, _ new: URL) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(new as CFURL, [], &code) == errSecSuccess, let code,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate), nil) == errSecSuccess
        else { return false }
        guard let ours = team(current) else { return true }
        return team(new) == ours
    }

    static func team(_ app: URL) -> String? {
        var code: SecStaticCode?
        var details: CFDictionary?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
              SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &details) == errSecSuccess
        else { return nil }
        return (details as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }

    /// Puts the new app exactly where the old one is, in one step.
    static func swap(_ new: URL, into app: URL) throws {
        guard (try? FileManager.default.replaceItemAt(app, withItemAt: new)) != nil else { throw Problem.place }
    }

    /// Starts the app again once this copy has quit, then quits.
    @MainActor
    private static func relaunch(_ app: URL) {
        let wait = Process()
        wait.executableURL = URL(fileURLWithPath: "/bin/sh")
        // "$0" is the app's path, passed separately so nothing in it is read as a command.
        wait.arguments = ["-c", "while /bin/kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"", app.path]
        if (try? wait.run()) != nil {
            NSApp.terminate(nil)
        } else {
            // No shell to wait with: start the new copy next to this one, then leave.
            let fresh = NSWorkspace.OpenConfiguration()
            fresh.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: app, configuration: fresh) { _, _ in
                Task { @MainActor in NSApp.terminate(nil) }
            }
        }
    }
}
