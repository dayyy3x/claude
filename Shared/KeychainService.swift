import Foundation
import Security

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
    case itemNotFound
    case encoding
}

/// Access-group-aware keychain wrapper used for WireGuard private keys and PSKs.
/// The access group is shared so the Packet Tunnel extension can read the same keys.
struct KeychainService {
    static let shared = KeychainService()

    private let service = "com.davidwilliams.ultronvpn.secrets"
    private var accessGroup: String? {
        // Leave nil in simulator so items are readable without the shared group.
        #if targetEnvironment(simulator)
        return nil
        #else
        return SharedConstants.keychainAccessGroup
        #endif
    }

    private func baseQuery(account: String) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        if let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
        return q
    }

    func set(_ value: String, for account: String) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainError.encoding }
        try setData(data, for: account)
    }

    func setData(_ data: Data, for account: String) throws {
        var query = baseQuery(account: account)
        let attrs: [String: Any] = [kSecValueData as String: data]

        let existing = SecItemCopyMatching(query as CFDictionary, nil)
        switch existing {
        case errSecSuccess:
            let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
            if status != errSecSuccess { throw KeychainError.unexpectedStatus(status) }
        case errSecItemNotFound:
            query.merge(attrs) { _, new in new }
            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess { throw KeychainError.unexpectedStatus(status) }
        default:
            throw KeychainError.unexpectedStatus(existing)
        }
    }

    func string(for account: String) throws -> String {
        let data = try data(for: account)
        guard let s = String(data: data, encoding: .utf8) else { throw KeychainError.encoding }
        return s
    }

    func data(for account: String) throws -> Data {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        switch status {
        case errSecSuccess:
            guard let data = out as? Data else { throw KeychainError.encoding }
            return data
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}
