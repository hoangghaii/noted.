import Foundation
import Security

/// Device-only, non-synchronizing secret. Never part of the library or backup manifest.
struct APIKeyStore {
    var service = (Bundle.main.bundleIdentifier ?? "Noted") + ".RemoteTextGenerator"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "api-key"]
    }

    func read() throws -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { throw KeyError.unavailable }
        return value
    }

    func save(_ value: String) throws {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { try delete(); return }
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8),
                                        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var request = query
            attributes.forEach { request[$0.key] = $0.value }
            guard SecItemAdd(request as CFDictionary, nil) == errSecSuccess else { throw KeyError.unavailable }
        } else if status != errSecSuccess { throw KeyError.unavailable }
    }

    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeyError.unavailable }
    }

    enum KeyError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Không truy cập được khóa API trong Keychain. Hãy mở khóa iPhone và thử lại." }
    }
}
