import Foundation
import Security

/// Almacenamiento mínimo en Keychain para credenciales y cookies de sesión.
///
/// Los ítems quedan ligados a este dispositivo (`ThisDeviceOnly`) y nunca se
/// sincronizan por iCloud Keychain. Es un llavero privado de la app, distinto
/// del Llavero de iCloud que ve el usuario.
struct KeychainStore {
    private var service: String {
        Bundle.main.bundleIdentifier ?? "com.focusartetv.FocusarteTV"
    }

    /// Crea el ítem o actualiza el existente. Devuelve el `OSStatus` de Security.
    @discardableResult
    func save(_ data: Data, _ account: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updated = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updated == errSecSuccess {
            return updated
        }
        guard updated == errSecItemNotFound else {
            return updated
        }

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        attributes[kSecAttrSynchronizable as String] = kCFBooleanFalse
        return SecItemAdd(attributes as CFDictionary, nil)
    }

    func read(_ account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    @discardableResult
    func delete(_ account: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary)
    }

    @discardableResult
    func saveString(_ value: String, _ account: String) -> OSStatus {
        save(Data(value.utf8), account)
    }

    func readString(_ account: String) -> String? {
        guard let data = read(account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
