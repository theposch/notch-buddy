import Foundation
import Security

/// Reads a saved password from the Mac's login Keychain.
enum Keychain {
    enum Result: Equatable { case found(Data), needsOK, missing }

    private static let lock = NSLock()

    /// Without `asking`, macOS may not show its prompt, so nothing pops up while you work.
    /// The newer way to say that (LAContext.interactionNotAllowed) doesn't cover the login
    /// Keychain, so this uses the older switch, which is for the whole app: hence the lock.
    static func read(_ service: String, asking: Bool) -> Result {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        lock.lock()
        SecKeychainSetUserInteractionAllowed(asking)
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        SecKeychainSetUserInteractionAllowed(true)
        lock.unlock()
        LoginUsage.log.notice("keychain read \(service, privacy: .public) (asking: \(asking, privacy: .public)): \(status, privacy: .public)")
        switch status {
        case errSecSuccess: return (result as? Data).map(Result.found) ?? .missing
        case errSecItemNotFound: return .missing
        default: return .needsOK   // not allowed yet, or you said no
        }
    }
}
