import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Respuesta HTTP normalizada e independiente de la plataforma.
public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let url: URL?
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, url: URL?, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.url = url
        self.headers = headers
        self.body = body
    }

    public var text: String {
        String(decoding: body, as: UTF8.self)
    }

    /// Búsqueda de header case-insensitive.
    public func header(_ name: String) -> String? {
        if let exact = headers[name] { return exact }
        let target = name.lowercased()
        return headers.first { $0.key.lowercased() == target }?.value
    }

    public var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
}

/// Abstracción de transporte para poder testear el cliente sin red.
public protocol HTTPTransport: Sendable {
    func perform(_ request: URLRequest) async throws -> HTTPResponse
}

/// Implementación real con URLSession.
///
/// Dos decisiones importantes:
///
/// 1. Las cookies se manejan a mano (`httpShouldSetCookies = false`) para que el
///    estado de sesión sea explícito y serializable a Keychain.
/// 2. Los redirects se **bloquean** en el delegate. Si los sigue URLSession,
///    el cliente nunca ve el 302 del login y, sobre todo, **pierde los
///    `Set-Cookie`** que vienen en ese redirect: la sesión queda sin cookie y
///    el siguiente request vuelve a caer en `/login`.
public final class URLSessionTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession
    private let redirectBlocker: RedirectBlocker

    public init(timeout: TimeInterval = 30) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2

        let blocker = RedirectBlocker()
        redirectBlocker = blocker
        session = URLSession(configuration: configuration, delegate: blocker, delegateQueue: nil)
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    public func perform(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw KajabiError.network("Respuesta no HTTP para \(request.url?.absoluteString ?? "?")")
        }

        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            guard let key = key as? String, let value = value as? String else { continue }
            headers[key] = value
            // Normalizamos los headers que el resto del código necesita con
            // nombre canónico; Foundation los entrega con el casing del server.
            switch key.lowercased() {
            case "set-cookie": headers["Set-Cookie"] = value
            case "location": headers["Location"] = value
            case "content-type": headers["Content-Type"] = value
            default: break
            }
        }

        return HTTPResponse(
            statusCode: http.statusCode,
            url: http.url ?? request.url,
            headers: headers,
            body: data
        )
    }
}

/// Corta la cadena de redirects para que el cliente HTTP los resuelva a mano.
private final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
