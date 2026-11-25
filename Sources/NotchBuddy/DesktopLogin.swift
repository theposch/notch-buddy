import CommonCrypto
import Foundation
import SQLite3

/// The Claude desktop app's own login: its claude.ai cookie, which it keeps encrypted the way
/// every Chromium-based app does, with a key in the Keychain ("Claude Safe Storage").
/// Read only to ask claude.ai for usage. Nothing is saved or sent anywhere else.
enum DesktopLogin {
    static let cookies = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/Claude/Cookies")
    static let keychainItem = "Claude Safe Storage"

    enum Result: Equatable, Sendable { case found(session: String, org: String), needsOK, missing }

    /// The claude.ai login and the organization it last used. Without `asking`,
    /// macOS isn't allowed to show its prompt.
    static func read(asking: Bool) -> Result {
        guard let (rows, version) = cookieRows(), let session = rows["sessionKey"], let org = rows["lastActiveOrg"] else { return .missing }
        let password: Data
        switch Keychain.read(keychainItem, asking: asking) {
        case .found(let data): password = data
        case .needsOK: return .needsOK
        case .missing: return .missing
        }
        let key = derivedKey(password), checked = version >= 24
        guard let sessionKey = decrypt(session, key: key, checked: checked),
              let orgID = decrypt(org, key: key, checked: checked),
              orgID.wholeMatch(of: /[0-9A-Za-z-]{1,64}/) != nil else { return .missing }
        return .found(session: sessionKey, org: orgID)
    }

    // MARK: The cookie file

    /// Encrypted claude.ai cookies by name, and the file's version, read without disturbing the app that owns it.
    private static func cookieRows() -> ([String: Data], Int)? {
        var db: OpaquePointer?
        let uri = "file:\(cookies.path)?immutable=1"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        var version = 0
        if sqlite3_prepare_v2(db, "select value from meta where key = 'version'", -1, &statement, nil) == SQLITE_OK,
           sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) {
            version = Int(String(cString: text)) ?? 0
        }
        sqlite3_finalize(statement)
        let sql = "select name, encrypted_value, host_key from cookies where host_key in ('claude.ai', '.claude.ai') and name in ('sessionKey', 'lastActiveOrg')"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        var rows: [String: Data] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let name = sqlite3_column_text(statement, 0), let bytes = sqlite3_column_blob(statement, 1) else { continue }
            rows[String(cString: name)] = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 1)))
        }
        return (rows, version)
    }

    // MARK: Unlocking it

    /// Chromium on the Mac: PBKDF2-SHA1 of the Keychain password, salt "saltysalt", 1003 rounds, 16 bytes.
    static func derivedKey(_ password: Data) -> Data {
        var key = Data(count: kCCKeySizeAES128)
        let salt = Data("saltysalt".utf8)
        _ = key.withUnsafeMutableBytes { out in
            password.withUnsafeBytes { pass in
                salt.withUnsafeBytes { salt in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), pass.baseAddress, password.count,
                                         salt.baseAddress, salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1), 1003,
                                         out.baseAddress, kCCKeySizeAES128)
                }
            }
        }
        return key
    }

    /// "v10" + AES-128-CBC (IV of 16 spaces). `checked`: newer cookie files put a 32-byte check of the
    /// site's name in front of the value; it's dropped.
    static func decrypt(_ value: Data, key: Data, checked: Bool) -> String? {
        guard value.starts(with: Data("v10".utf8)) else { return String(data: value, encoding: .utf8) }
        let sealed = value.dropFirst(3)
        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)
        var out = Data(count: sealed.count + kCCBlockSizeAES128)
        var length = 0
        let status = out.withUnsafeMutableBytes { out in
            sealed.withUnsafeBytes { sealed in
                key.withUnsafeBytes { key in
                    iv.withUnsafeBytes { iv in
                        CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                                key.baseAddress, key.count, iv.baseAddress, sealed.baseAddress, sealed.count,
                                out.baseAddress, out.count, &length)
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        let plain = out.prefix(length)
        return String(data: checked ? plain.dropFirst(32) : plain, encoding: .utf8)
    }
}
