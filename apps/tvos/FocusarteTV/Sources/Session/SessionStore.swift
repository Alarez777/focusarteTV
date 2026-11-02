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
    /// Lecciones que ya sabemos si tienen video (se llena con el prefetch).
    private var lessonVideo: [String: Bool] = [:]
    /// Datos mínimos para lanzar el player desde el carrusel sin abrir el post.
    private struct PlaybackInfo {
        let mediaID: String
        let posterURL: URL?
        let progressToken: String
        let title: String
    }
    private var playbackInfo: [String: PlaybackInfo] = [:]
    /// Cola de prefetch de posters. Se reordena sin cancelar el trabajo en curso.
    private var prefetchQueue: [LessonSummary] = []
    private var prefetchWorker: Task<Void, Never>?
    /// Invalida escrituras de cookies que quedaron en vuelo tras cerrar sesión.
    private var sessionGeneration = 0
    private static let emailAccount = "focusarte.email"
    private static let posterCacheKey = "lesson_poster_urls"
    private static let videoFlagsKey = "lesson_video_flags"
    private static let passwordAccount = "focusarte.password"
    private static let cookiesAccount = "focusarte.cookies"

    init(client: KajabiClient = KajabiClient(), keychain: KeychainStore = KeychainStore()) {
        self.client = client
        self.keychain = keychain

        if let stored = UserDefaults.standard.dictionary(forKey: Self.posterCacheKey) as? [String: String] {
            posterCache = stored.compactMapValues { URL(string: $0) }
        }
        if let stored = UserDefaults.standard.dictionary(forKey: Self.videoFlagsKey) as? [String: Bool] {
            lessonVideo = stored
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
        sessionGeneration += 1
        PlaybackManager.shared.stop()
        await client.clearSession()
        keychain.delete(Self.cookiesAccount)
        keychain.delete(Self.passwordAccount)
        keychain.delete(Self.emailAccount)
        PlaybackPreferences.shared.reset()
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

    /// `nil` si todavía no se cargó la página de esa lección.
    func lessonHasVideo(_ lessonID: String) -> Bool? {
        lessonVideo[lessonID]
    }

    /// Reordena la cola de prefetch. El worker sigue trabajando hasta vaciarla;
    /// si el usuario cambia de bloque solo cambia la prioridad.
    func prefetchPosters(ordered lessons: [LessonSummary]) {
        prefetchQueue = lessons
        guard prefetchWorker == nil else { return }

        prefetchWorker = Task { [weak self] in
            await self?.drainPrefetchQueue()
            self?.prefetchWorker = nil
        }
    }

    private func drainPrefetchQueue() async {
        let client = self.client
        let window = 3

        while !Task.isCancelled, !prefetchQueue.isEmpty {
            let batch = Array(prefetchQueue.prefix(window))
            prefetchQueue.removeFirst(min(window, prefetchQueue.count))

            await withTaskGroup(of: (String, Lesson?).self) { group in
                for lesson in batch {
                    guard posterCache[lesson.id] == nil,
                          !posterTasks.contains(lesson.id) else { continue }

                    posterTasks.insert(lesson.id)
                    group.addTask {
                        (lesson.id, try? await client.loadLesson(path: lesson.path))
                    }
                }

                for await (id, loaded) in group {
                    if let loaded {
                        if let url = loaded.posterURL {
                            posterCache[id] = url
                            persistPosterCache()
                        }
                        lessonVideo[id] = loaded.video != nil
                        if let video = loaded.video {
                            playbackInfo[id] = PlaybackInfo(
                                mediaID: video.mediaID,
                                posterURL: loaded.posterURL,
                                progressToken: loaded.progressToken,
                                title: loaded.title
                            )
                        }
                    }
                    posterTasks.remove(id)
                }
            }

            persistVideoFlags()
        }
    }

    private func persistVideoFlags() {
        UserDefaults.standard.set(lessonVideo, forKey: Self.videoFlagsKey)
    }

    // MARK: - Reproducción

    /// Lanza el player desde el carrusel. Devuelve `false` si la lección no
    /// tiene video (entonces corresponde abrir el post).
    @discardableResult
    func startPlayback(
        summary: LessonSummary,
        sectionTitle: String,
        courseTitle: String,
        courseSlug: String
    ) async -> Bool {
        guard let info = await playbackInfo(for: summary),
              let asset = try? await client.resolveVideo(mediaID: info.mediaID),
              let url = asset.playbackURL else {
            return false
        }

        PlaybackManager.shared.play(
            key: summary.id,
            url: url,
            duration: asset.duration,
            progressToken: info.progressToken,
            client: client,
            metadata: PlaybackMetadata(
                title: info.title,
                courseTitle: courseTitle,
                sectionTitle: sectionTitle,
                artworkURL: info.posterURL ?? asset.posterURL
            ),
            courseSlug: courseSlug,
            nextProvider: makeNextProvider(courseSlug: courseSlug, courseTitle: courseTitle)
        )
        return true
    }

    private func playbackInfo(for summary: LessonSummary) async -> PlaybackInfo? {
        if let cached = playbackInfo[summary.id] {
            return cached
        }

        guard let lesson = try? await client.loadLesson(path: summary.path) else {
            return nil
        }

        lessonVideo[summary.id] = lesson.video != nil
        guard let video = lesson.video else { return nil }

        let info = PlaybackInfo(
            mediaID: video.mediaID,
            posterURL: lesson.posterURL,
            progressToken: lesson.progressToken,
            title: lesson.title
        )
        playbackInfo[summary.id] = info
        return info
    }

    /// Resuelve la próxima lección reproducible a partir del outline cacheado.
    func makeNextProvider(courseSlug: String, courseTitle: String) -> PlaybackManager.NextProvider? {
        guard let outline = outlineCache[courseSlug] else { return nil }

        let flat: [(section: String, lesson: LessonSummary)] = outline.sections.flatMap { section in
            section.lessons.map { (section.title, $0) }
        }
        let client = self.client

        return { currentKey in
            guard let index = flat.firstIndex(where: { $0.lesson.id == currentKey }),
                  index + 1 < flat.count else {
                return nil
            }

            // Solo mira la lección inmediatamente siguiente: si es un post se
            // abre el post en vez de saltearlo.
            let candidate = flat[index + 1]
            guard let lesson = try? await client.loadLesson(path: candidate.lesson.path) else {
                return nil
            }

            guard let video = lesson.video else {
                return .post(key: lesson.id)
            }

            guard let asset = try? await client.resolveVideo(mediaID: video.mediaID),
                  let url = asset.playbackURL else {
                return nil
            }

            return .video(
                UpNextLesson(
                    key: lesson.id,
                    url: url,
                    duration: asset.duration,
                    progressToken: lesson.progressToken,
                    client: client,
                    metadata: PlaybackMetadata(
                        title: lesson.title,
                        courseTitle: courseTitle,
                        sectionTitle: candidate.section,
                        artworkURL: lesson.posterURL ?? asset.posterURL
                    )
                )
            )
        }
    }

    private func persistPosterCache() {
        UserDefaults.standard.set(
            posterCache.mapValues(\.absoluteString),
            forKey: Self.posterCacheKey
        )
    }

    /// Tamaño aproximado de lo que liberaría "Eliminar caché".
    var cacheSizeBytes: Int {
        let images = ImageStore.shared.cacheBytes
        let mapBytes: Int
        if let stored = UserDefaults.standard.dictionary(forKey: Self.posterCacheKey) as? [String: String] {
            mapBytes = stored.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count }
        } else {
            mapBytes = 0
        }
        return images + mapBytes
    }

    /// Borra outlines, posters en memoria, el mapa persistido y las imágenes.
    func clearCaches() {
        outlineCache.removeAll()
        posterCache.removeAll()
        posterTasks.removeAll()
        lessonVideo.removeAll()
        playbackInfo.removeAll()
        prefetchWorker?.cancel()
        prefetchWorker = nil
        prefetchQueue.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.posterCacheKey)
        UserDefaults.standard.removeObject(forKey: Self.videoFlagsKey)
        ImageStore.shared.clear()
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
        let generation = sessionGeneration
        Task { [weak self] in
            guard let self else { return }
            let snapshot = await self.client.cookieSnapshot
            guard generation == self.sessionGeneration else { return }
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
