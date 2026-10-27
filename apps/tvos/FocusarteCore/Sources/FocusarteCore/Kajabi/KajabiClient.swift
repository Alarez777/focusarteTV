import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Cliente de Focusarte (Kajabi) basado en HTTP + HTML.
///
/// Es un `actor` para que el tarro de cookies y el token CSRF tengan un único
/// dueño aunque la UI dispare requests en paralelo.
public actor KajabiClient {

    public static let defaultBaseURL = URL(string: "https://www.focusarte.com")!
    public static let defaultUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

    public let baseURL: URL

    private let transport: HTTPTransport
    private let userAgent: String
    private var cookies: CookieJar
    private var csrfToken: String?

    public init(
        baseURL: URL = KajabiClient.defaultBaseURL,
        transport: HTTPTransport = URLSessionTransport(),
        cookies: [String: String] = [:],
        userAgent: String = KajabiClient.defaultUserAgent
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.cookies = CookieJar(cookies)
        self.userAgent = userAgent
    }

    // MARK: - Estado de sesión

    public var cookieSnapshot: [String: String] { cookies.raw }

    public var isAuthenticated: Bool {
        cookies["_kjb_session"] != nil || cookies["remember_member_token"] != nil
    }

    public var currentCSRFToken: String? { csrfToken }

    public func restoreCookies(_ raw: [String: String]) {
        cookies = CookieJar(raw)
    }

    public func clearSession() {
        cookies.removeAll()
        csrfToken = nil
    }

    // MARK: - Login

    /// Inicia sesión con el formulario clásico de Kajabi.
    /// - Throws: `KajabiError.invalidCredentials` si el sitio rechaza las credenciales.
    @discardableResult
    public func signIn(email: String, password: String) async throws -> Bool {
        let loginPage = try await perform("/login")
        refreshCSRF(from: loginPage.text)

        guard let authenticity = KajabiHTML.authenticityToken(from: loginPage.text) ?? csrfToken else {
            throw KajabiError.parsing("no se encontró authenticity_token en /login")
        }

        let response = try await perform(
            "/login",
            method: "POST",
            form: [
                "authenticity_token": authenticity,
                "member[email]": email,
                "member[password]": password,
                "member[remember_me]": "1"
            ],
            treatLoginRedirectAsExpiry: false
        )
        refreshCSRF(from: response.text)

        if response.url?.path.hasSuffix("/login") == true {
            let message = KajabiHTML.loginErrorMessage(from: response.text)
            throw KajabiError.invalidCredentials(message ?? "Email o contraseña incorrectos.")
        }

        guard isAuthenticated else {
            throw KajabiError.invalidCredentials("El sitio no devolvió una sesión.")
        }
        return true
    }

    /// Verifica que la sesión siga viva.
    public func validateSession() async throws {
        _ = try await loadLibrary()
    }

    // MARK: - Contenido

    public func loadLibrary() async throws -> [Course] {
        let response = try await perform("/library")
        refreshCSRF(from: response.text)
        return try KajabiHTML.parseLibrary(response.text, baseURL: baseURL)
    }

    public func loadCourse(slug: String) async throws -> CourseOutline {
        let response = try await perform("/products/\(slug)")
        refreshCSRF(from: response.text)
        return try KajabiHTML.parseCourse(response.text, slug: slug)
    }

    public func loadLesson(path: String) async throws -> Lesson {
        let response = try await perform(path)
        refreshCSRF(from: response.text)
        return try KajabiHTML.parseLesson(response.text, path: path)
    }

    /// Descarga un adjunto (PDF, etc.) usando la sesión del miembro.
    public func download(path: String) async throws -> Data {
        let response = try await perform(path)
        guard response.isSuccess else {
            throw KajabiError.unexpectedStatus(response.statusCode)
        }
        return response.body
    }

    // MARK: - Video

    /// Wistia no requiere cookies: el JSON de media es público.
    public func resolveVideo(mediaID: String) async throws -> VideoAsset {
        guard let url = Wistia.mediaJSONURL(mediaID: mediaID) else {
            throw KajabiError.parsing("mediaID inválido: \(mediaID)")
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(baseURL.absoluteString + "/", forHTTPHeaderField: "Referer")

        let response = try await transport.perform(request)
        guard response.isSuccess else {
            throw KajabiError.unexpectedStatus(response.statusCode)
        }
        return try Wistia.parseMedia(json: response.body, mediaID: mediaID)
    }

    // MARK: - Progreso

    public func setCompleted(_ completed: Bool, token: String) async throws {
        guard !token.isEmpty else { throw KajabiError.parsing("lección sin token de progreso") }

        var form = ["token": token]
        if !completed {
            form["_method"] = "DELETE"
        }

        let response = try await perform("/tracking/completion", method: "POST", form: form)
        guard response.isSuccess else {
            throw KajabiError.unexpectedStatus(response.statusCode)
        }
    }

    /// Reporta segundos y porcentaje vistos. Kajabi solo guarda si el porcentaje
    /// supera al que ya tenía.
    public func reportProgress(token: String, seconds: Double, percent: Int) async throws {
        guard !token.isEmpty, percent > 0 else { return }

        let response = try await perform(
            "/tracking/progress",
            method: "POST",
            form: [
                "token": token,
                "progress_seconds": String(Int(max(seconds, 0))),
                "progress_percent": String(min(percent, 100))
            ]
        )
        guard response.isSuccess else {
            throw KajabiError.unexpectedStatus(response.statusCode)
        }
    }

    // MARK: - HTTP

    private func perform(
        _ path: String,
        method: String = "GET",
        form: [String: String]? = nil,
        treatLoginRedirectAsExpiry: Bool = true
    ) async throws -> HTTPResponse {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw KajabiError.network("URL inválida: \(path)")
        }

        var currentURL = url
        var currentMethod = method
        var body = form.map(Self.formEncode)
        var redirects = 0

        while true {
            var request = URLRequest(url: currentURL)
            request.httpMethod = currentMethod
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue(
                "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8",
                forHTTPHeaderField: "Accept"
            )
            request.setValue("es-ES,es;q=0.9", forHTTPHeaderField: "Accept-Language")

            if !cookies.isEmpty {
                request.setValue(cookies.header, forHTTPHeaderField: "Cookie")
            }
            if let body {
                request.httpBody = body
                request.setValue(
                    "application/x-www-form-urlencoded; charset=UTF-8",
                    forHTTPHeaderField: "Content-Type"
                )
            }
            if currentMethod != "GET" {
                request.setValue(baseURL.absoluteString + "/", forHTTPHeaderField: "Origin")
                if let csrfToken {
                    request.setValue(csrfToken, forHTTPHeaderField: "X-CSRF-Token")
                }
            }

            let response = try await transport.perform(request)
            absorbCookies(from: response)

            if (300..<400).contains(response.statusCode),
               let location = response.header("Location"),
               let next = URL(string: location, relativeTo: currentURL)?.absoluteURL {
                redirects += 1
                if redirects > 8 {
                    throw KajabiError.network("demasiados redirects desde \(path)")
                }
                if response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 303 {
                    currentMethod = "GET"
                    body = nil
                }
                currentURL = next
                continue
            }

            if treatLoginRedirectAsExpiry,
               !path.hasSuffix("/login"),
               let finalPath = response.url?.path,
               finalPath.hasSuffix("/login") {
                throw KajabiError.sessionExpired
            }

            return response
        }
    }

    private func absorbCookies(from response: HTTPResponse) {
        guard let url = response.url else { return }
        let found = HTTPCookie.cookies(withResponseHeaderFields: response.headers, for: url)
        cookies.absorb(found)
    }

    private func refreshCSRF(from html: String) {
        if let token = KajabiHTML.csrfToken(from: html) {
            csrfToken = token
        }
    }

    private static func formEncode(_ form: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")

        let encoded = form
            .map { pair -> String in
                let key = pair.key.addingPercentEncoding(withAllowedCharacters: allowed) ?? pair.key
                let value = pair.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? pair.value
                return "\(key)=\(value)"
            }
            .sorted()
            .joined(separator: "&")

        return Data(encoded.utf8)
    }
}
