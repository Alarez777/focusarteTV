import Foundation
import Combine
import MediaPlayer
import FocusarteCore

/// Dueño único del playback de la app.
///
/// Retiene el `PlayerHostViewController` (y con él al delegate de PiP) aunque
/// el cover de SwiftUI se desmonte, para que el video flotante se pueda
/// restaurar a pantalla completa. También maneja el Up Next y el autoplay.
@MainActor
final class PlaybackManager: ObservableObject {
    static let shared = PlaybackManager()

    typealias NextProvider = @MainActor (String) async -> UpNextLesson?

    struct Session: Identifiable {
        let id = UUID()
        let key: String
        let host: PlayerHostViewController
        let duration: TimeInterval
        let progressToken: String
        let client: KajabiClient
        let metadata: PlaybackMetadata
        let courseSlug: String
        let nextProvider: NextProvider?
    }

    @Published var presented: Session?
    @Published private(set) var isPictureInPictureActive = false
    @Published private(set) var upNext: UpNextLesson?
    @Published private(set) var upNextCountdown: Int?
    /// Lección que está sonando (sigue al auto-avance).
    @Published private(set) var currentLessonKey: String?
    /// Se incrementa después de reportar progreso, para que la UI refresque
    /// recién cuando el servidor ya tiene el dato.
    @Published private(set) var progressRevision = 0

    private(set) var active: Session?
    private var upNextCancelled = false
    private var resolvingNext = false
    private var ended = false

    private init() {}

    // MARK: - API

    func play(
        key: String,
        url: URL,
        duration: TimeInterval,
        progressToken: String,
        client: KajabiClient,
        metadata: PlaybackMetadata,
        courseSlug: String,
        nextProvider: NextProvider?
    ) {
        // El mismo video está flotando en PiP: volver a pantalla completa.
        if isPictureInPictureActive, let active, active.key == key {
            presented = active
            return
        }

        stop()
        startSession(
            key: key,
            url: url,
            duration: duration,
            progressToken: progressToken,
            client: client,
            metadata: metadata,
            courseSlug: courseSlug,
            nextProvider: nextProvider
        )
    }

    func stop() {
        active?.host.teardown()
        active = nil
        presented = nil
        upNext = nil
        upNextCountdown = nil
        upNextCancelled = false
        resolvingNext = false
        ended = false
        isPictureInPictureActive = false
        currentLessonKey = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Llamado desde `dismantleUIViewController` cuando SwiftUI suelta el cover.
    func hostWasDismantled(_ host: PlayerHostViewController) {
        guard let active, active.host === host else { return }

        // Si está en PiP, el host debe seguir vivo para poder restaurarlo.
        if host.isPictureInPictureActive {
            host.detachFromScreen()
            return
        }

        let seconds = host.currentSeconds
        let percent = percentFor(seconds: seconds, duration: host.duration)
        finishActive(seconds: seconds.isFinite ? seconds : 0, percent: percent)
        stop()
    }

    // MARK: - Sesión

    private func startSession(
        key: String,
        url: URL,
        duration: TimeInterval,
        progressToken: String,
        client: KajabiClient,
        metadata: PlaybackMetadata,
        courseSlug: String,
        nextProvider: NextProvider?
    ) {
        let host = PlayerHostViewController()
        host.loadViewIfNeeded()
        host.configure(
            key: key,
            url: url,
            duration: duration,
            metadata: metadata,
            onFinish: { [weak self] seconds, percent in
                self?.handlePlaybackEnded(seconds: seconds, percent: percent)
            },
            onTick: { [weak self] remaining in
                self?.handleTick(remaining)
            },
            onPiPChange: { [weak self] active in
                self?.isPictureInPictureActive = active
                if !active {
                    self?.pictureInPictureDidStop()
                }
            },
            onRestore: { [weak self] in
                self?.restoreFromPictureInPicture()
            }
        )

        let session = Session(
            key: key,
            host: host,
            duration: duration,
            progressToken: progressToken,
            client: client,
            metadata: metadata,
            courseSlug: courseSlug,
            nextProvider: nextProvider
        )

        active = session
        presented = session
        currentLessonKey = key
        upNext = nil
        upNextCountdown = nil
        upNextCancelled = false
        resolvingNext = false
        ended = false

        MPNowPlayingInfoCenter.default().nowPlayingInfo = metadata.nowPlayingInfo(duration: duration)
        PlaybackPreferences.shared.remember(courseSlug: courseSlug, lessonID: key)
        host.play()
    }

    // MARK: - Up Next

    private func handleTick(_ remaining: Double) {
        guard !ended else { return }

        guard PlaybackPreferences.shared.autoplayNextLesson else {
            if upNext != nil {
                upNext = nil
                upNextCountdown = nil
                updateContextualActions()
            }
            return
        }

        guard !upNextCancelled else { return }
        guard remaining > 0, remaining <= 5 else { return }

        upNextCountdown = max(0, Int(remaining.rounded()))

        if upNext == nil, !resolvingNext {
            resolveNext()
        }
    }

    private func resolveNext() {
        guard let session = active, let provider = session.nextProvider else { return }
        resolvingNext = true
        let key = session.key

        Task {
            let next = await provider(key)
            resolvingNext = false

            guard !upNextCancelled, !ended else { return }
            if let next {
                upNext = next
                updateContextualActions()
            }
        }
    }

    private func updateContextualActions() {
        guard let host = active?.host else { return }
        let show = upNext != nil
            && PlaybackPreferences.shared.autoplayNextLesson
            && !upNextCancelled
            && !ended

        host.setContextualActions(
            active: show,
            onNext: { [weak self] in self?.advanceToNext() },
            onCancel: { [weak self] in self?.cancelUpNext() }
        )
    }

    func cancelUpNext() {
        upNextCancelled = true
        upNext = nil
        upNextCountdown = nil
        updateContextualActions()
    }

    func advanceToNext() {
        guard let next = upNext else { return }
        upNext = nil
        upNextCountdown = nil
        playNext(next)
    }

    private func handlePlaybackEnded(seconds: Double, percent: Int) {
        guard !ended else { return }
        ended = true

        finishActive(seconds: seconds, percent: percent)
        active?.host.setContextualActions(active: false, onNext: {}, onCancel: {})

        guard PlaybackPreferences.shared.autoplayNextLesson, !upNextCancelled else {
            stop()
            return
        }

        if let next = upNext {
            playNext(next)
            return
        }

        guard let session = active, let provider = session.nextProvider else {
            stop()
            return
        }

        let key = session.key
        Task {
            if let next = await provider(key) {
                playNext(next)
            } else {
                stop()
            }
        }
    }

    private func playNext(_ next: UpNextLesson) {
        guard let current = active else { return }

        current.host.setContextualActions(active: false, onNext: {}, onCancel: {})
        current.host.teardown()

        startSession(
            key: next.key,
            url: next.url,
            duration: next.duration,
            progressToken: next.progressToken,
            client: next.client,
            metadata: next.metadata,
            courseSlug: current.courseSlug,
            nextProvider: current.nextProvider
        )
    }

    // MARK: - Progreso

    private func finishActive(seconds: Double, percent: Int) {
        guard let active, percent > 0 else { return }
        let token = active.progressToken
        let client = active.client
        let shouldComplete = percent >= 90

        Task {
            try? await client.reportProgress(token: token, seconds: seconds, percent: percent)
            if shouldComplete {
                try? await client.setCompleted(true, token: token)
            }
            progressRevision += 1
        }
    }

    private func percentFor(seconds: Double, duration: TimeInterval) -> Int {
        guard seconds.isFinite, duration > 0 else { return 0 }
        return min(max(Int((seconds / duration) * 100), 0), 100)
    }

    // MARK: - PiP

    private func restoreFromPictureInPicture() {
        guard let active else { return }
        presented = active
    }

    private func pictureInPictureDidStop() {
        // Si no hay cover presentado, el usuario cerró la ventana flotante.
        if presented == nil {
            stop()
        }
    }
}
