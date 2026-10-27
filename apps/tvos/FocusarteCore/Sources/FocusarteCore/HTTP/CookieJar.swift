import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Tarro de cookies propio: nombre → valor.
///
/// No usamos `HTTPCookieStorage` porque su comportamiento varía entre Darwin y
/// Linux y porque necesitamos serializar la sesión a Keychain sin sorpresas.
public struct CookieJar: Sendable, Equatable {
    private var storage: [String: String]

    public init(_ raw: [String: String] = [:]) {
        self.storage = raw
    }

    public var raw: [String: String] { storage }

    public var isEmpty: Bool { storage.isEmpty }

    public subscript(name: String) -> String? {
        storage[name]
    }

    /// `name=value; name2=value2` listo para el header `Cookie`.
    public var header: String {
        storage
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "; ")
    }

    /// Incorpora cookies de una respuesta. Las cookies con expiración pasada
    /// (usadas por Rails para borrar) eliminan la entrada.
    public mutating func absorb(_ cookies: [HTTPCookie], now: Date = Date()) {
        for cookie in cookies {
            if let expires = cookie.expiresDate, expires <= now {
                storage[cookie.name] = nil
            } else {
                storage[cookie.name] = cookie.value
            }
        }
    }

    public mutating func set(_ name: String, _ value: String?) {
        storage[name] = value
    }

    public mutating func removeAll() {
        storage.removeAll()
    }
}
