import Foundation
import Security

// MARK: - Keychain Service

/// A stateless service for securely storing and retrieving credentials in the iOS Keychain.
enum KeychainService {

    // MARK: - Keys

    private static let accessTokenKey = "com.coachingapp.accessToken"
    private static let refreshTokenKey = "com.coachingapp.refreshToken"
    private static let serviceName = "com.coachingapp.auth"

    // MARK: - Access Token

    @discardableResult
    static func saveAccessToken(_ token: String) -> Bool {
        save(key: accessTokenKey, value: token)
    }

    static func loadAccessToken() -> String? {
        load(key: accessTokenKey)
    }

    @discardableResult
    static func deleteAccessToken() -> Bool {
        delete(key: accessTokenKey)
    }

    // MARK: - Refresh Token

    @discardableResult
    static func saveRefreshToken(_ token: String) -> Bool {
        save(key: refreshTokenKey, value: token)
    }

    static func loadRefreshToken() -> String? {
        load(key: refreshTokenKey)
    }

    @discardableResult
    static func deleteRefreshToken() -> Bool {
        delete(key: refreshTokenKey)
    }

    // MARK: - Generic Save

    /// Save a string value to the keychain under the given key.
    /// Overwrites any existing value for that key.
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }

        // Delete any existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Generic Load

    /// Load a string value from the keychain for the given key.
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    // MARK: - Generic Delete

    /// Delete a keychain item for the given key.
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Clear All

    /// Remove all keychain items for this service.
    @discardableResult
    static func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
