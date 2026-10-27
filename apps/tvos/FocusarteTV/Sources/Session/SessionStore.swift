import Foundation
import Combine
import FocusarteCore

@MainActor
final class SessionStore: ObservableObject {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn
    }

    @Published private(set) var state: State = .restoring
    @Published private(set) var courses: [Course] = []
    @Published private(set) var isLoading = false
    @Published private(set) var signedInEmail = ""
    @Published var errorMessage: String?

    let client: KajabiClient

    private let keychain: KeychainStore
    private var outlineCache: [String: CourseOutline] = [:]
    private static let emailAccount = "focusarte.email"
    private static let passwordAccount = "focusarte.password"
    private static let cookiesAccount = "focusarte.cookies"

    init(client: KajabiClient = KajabiClient(), keychain: KeychainStore = KeychainStore()) {
        self.client = client
        self.keychain = keychain
    }

    /// Restaura la sesión al arrancar: primero cookies guardadas, después
    /// re-login silencioso con las credenciales de Keychain.
    func restore() async {
        guard state == .restoring else { return }

        if let data = keychain.read(Self.cookiesAccount),
           let raw = try? JSONDecoder().decode([String: String].self, from: data),
           !raw.isEmpty {
            await client.restoreCookies(raw)
            if let loaded = try? await client.loadLibrary() {
                courses = loaded
                signedInEmail = keychain.readString(Self.emailAccount) ?? ""
                state = .signedIn
                return
            }
        }

        if let email = keychain.readString(Self.emailAccount),
           let password = keychain.readString(Self.passwordAccount),
           !email.isEmpty, !password.isEmpty {
            _ = await attemptSignIn(email: email, password: password)
            if state == .signedIn { return }
        }

        state = .signedOut
    }

    @discardableResult
    func signIn(email: String, password: String) async -> Bool {
        await attemptSignIn(email: email, password: password)
    }

    func signOut() async {
        await client.clearSession()
        keychain.delete(Self.cookiesAccount)
        keychain.delete(Self.passwordAccount)
        courses = []
        signedInEmail = ""
        outlineCache.removeAll()
        state = .signedOut
    }

    // MARK: - Cache de cursos

    /// Outline ya cargado en esta sesión, para mostrarlo al instante.
    func cachedOutline(for slug: String) -> CourseOutline? {
        outlineCache[slug]
    }

    /// Pide el outline al sitio y actualiza el cache.
    @discardableResult
    func loadOutline(slug: String) async throws -> CourseOutline {
        let outline = try await client.loadCourse(slug: slug)
        outlineCache[slug] = outline
        return outline
    }

    func reloadLibrary() async {
        do {
            courses = try await client.loadLibrary()
            persistCookies()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private func attemptSignIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await client.signIn(email: email, password: password)
            let loaded = try await client.loadLibrary()

            courses = loaded
            signedInEmail = email

            keychain.saveString(email, Self.emailAccount)
            keychain.saveString(password, Self.passwordAccount)
            persistCookies()

            state = .signedIn
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    private func persistCookies() {
        Task { [weak self] in
            guard let self else { return }
            let snapshot = await self.client.cookieSnapshot
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            self.keychain.save(data, Self.cookiesAccount)
        }
    }

    private static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
