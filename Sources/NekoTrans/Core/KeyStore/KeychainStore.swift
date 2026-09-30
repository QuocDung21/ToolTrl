import Foundation
import Security

/// Thin wrapper around the macOS Keychain used for every app secret
/// (LLM/translation API keys, GitHub PAT).
///
/// Secrets are generic-password items scoped to the app's bundle identifier and
/// are **never** written to `UserDefaults`, so they do not end up in
/// `~/Library/Preferences/*.plist` where any local process can read them.
public enum KeychainStore {

    /// `Bundle.main.bundleIdentifier` is empty in some hosts (e.g. `swift test`),
    /// so fall back to the shipping bundle identifier to keep one stable service.
    private static var service: String {
        Bundle.main.bundleIdentifier ?? "com.nekotrans.mac"
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// Stores `value` for `account`, replacing any previous item.
    /// An empty value deletes the item. Returns `true` when the Keychain reflects the request.
    @discardableResult
    public static func set(_ value: String, for account: String) -> Bool {
        guard !value.isEmpty else { return remove(account: account) }

        let data = Data(value.utf8)
        let query = baseQuery(account: account)

        // Upsert: update in place when the item already exists.
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    /// Reads the stored secret, or `nil` when it is absent or unreadable.
    public static func string(for account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    @discardableResult
    public static func remove(account: String) -> Bool {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// One-shot migration for installs that still hold a secret in `UserDefaults`.
    ///
    /// The legacy value is only dropped once the Keychain actually holds it, so a
    /// failed Keychain write can never lose the user's key.
    public static func migrateFromUserDefaults(account: String, defaults: UserDefaults = .standard) {
        guard let legacy = defaults.string(forKey: account), !legacy.isEmpty else { return }

        if string(for: account) == nil, !set(legacy, for: account) { return }
        defaults.removeObject(forKey: account)
    }

    /// Migrates every known secret account in one call.
    public static func migrateAllSecretsFromUserDefaults(defaults: UserDefaults = .standard) {
        for account in KeyStore.Secret.allAccounts {
            migrateFromUserDefaults(account: account, defaults: defaults)
        }
    }
}
