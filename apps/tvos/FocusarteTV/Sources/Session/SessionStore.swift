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
    private var posterCache: [String: URL] = [:]
    private var posterTasks: Set<String> = []
    private static let emailAccount = "focusarte.email"
    private static let posterCacheKey = "lesson_poster_urls"
    private static let passwordAccount = "focusarte.password"
    private static let cookiesAccount = "focusarte.cookies"

    init(client: KajabiClient = KajabiClient(), keychain: KeychainStore = KeychainStore()) {
        self.client = client
        self.keychain = keychain

        if let stored = UserDefaults.standard.dictionary(forKey: Self.posterCacheKey) as? [String: String] {
            posterCache = stored.compactMapValues { URL(string: $0) }
        }
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
        PlaybackManager.shared.stop()
        await client.clearSession()
        keychain.delete(Self.cookiesAccount)
        keychain.delete(Self.passwordAccount)
        courses = []
        signedInEmail = ""
        clearCaches()
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

    // MARK: - Miniaturas de lecciones

    func lessonPosterURL(for lessonID: String) -> URL? {
        posterCache[lessonID]
    }

    private var prefetchGeneration = 0

    /// Trae posters en el orden de prioridad indicado. Cada llamada invalida
    /// la anterior: si el usuario cambia de bloque, manda el nuevo orden.
    func prefetchPosters(ordered lessons: [LessonSummary]) {
        prefetchGeneration += 1
        let generation = prefetchGeneration
        Task {
            await runPrefetch(lessons, generation: generation)
        }
    }

    private func runPrefetch(_ lessons: [LessonSummary], generation: Int) async {
        let missing = lessons.filter {
            posterCache[$0.id] == nil && !posterTasks.contains($0.id)
        }
        guard !missing.isEmpty else { return }

        for lesson in missing {
            posterTasks.insert(lesson.id)
        }

        let client = self.client

        await withTaskGroup(of: (String, URL?).self) { group in
            var index = 0
            let window = 3

            while index < min(window, missing.count) {
                let lesson = missing[index]
                index += 1
                group.addTask {
                    let parsed = try? await client.loadLesson(path: lesson.path)
                    return (lesson.id, parsed?.posterURL)
                }
            }

            while let (id, url) = await group.next() {
                if let url {
                    posterCache[id] = url
                    persistPosterCache()
                }
                posterTasks.remove(id)

                guard generation == prefetchGeneration else { continue }
                guard index < missing.count else { continue }

                let lesson = missing[index]
                index += 1
                group.addTask {
                    let parsed = try? await client.loadLesson(path: lesson.path)
                    return (lesson.id, parsed?.posterURL)
                }
            }
        }
    }

    private func persistPosterCache() {
        UserDefaults.standard.set(
            posterCache.mapValues(\.absoluteString),
            forKey: Self.posterCacheKey
        )
    }

    /// Borra outlines, posters en memoria, el mapa persistido y las imágenes.
    func clearCaches() {
        outlineCache.removeAll()
        posterCache.removeAll()
        posterTasks.removeAll()
        prefetchGeneration += 1
        UserDefaults.standard.removeObject(forKey: Self.posterCacheKey)
        ImageStore.shared.clear()
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
