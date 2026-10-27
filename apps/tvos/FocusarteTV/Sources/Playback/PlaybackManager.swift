import Foundation
import AVFoundation
import Combine
import FocusarteCore

/// Dueño único del playback de la app.
///
/// Permite reutilizar el mismo `AVPlayer` cuando el usuario vuelve a elegir el
/// video que ya está reproduciendo (incluso en PiP) y presentarlo en grande en
/// lugar de crear uno nuevo.
@MainActor
final class PlaybackManager: ObservableObject {
    static let shared = PlaybackManager()

    struct Session: Identifiable {
        let id = UUID()
        let key: String
        let player: AVPlayer
        let duration: TimeInterval
        let progressToken: String
        let client: KajabiClient
    }

    /// Item del `fullScreenCover` a nivel raíz.
    @Published var presented: Session?
    @Published private(set) var isPictureInPictureActive = false

    private(set) var active: Session?

    private init() {}

    /// Devuelve el player para esta lección. Si ya hay uno activo con la misma
    /// key (reproduciendo, pausado o en PiP), lo reutiliza.
    func play(
        key: String,
        url: URL,
        duration: TimeInterval,
        progressToken: String,
        client: KajabiClient
    ) {
        if let active, active.key == key,
           isPictureInPictureActive || active.player.timeControlStatus != .paused {
            let session = Session(
                key: key,
                player: active.player,
                duration: duration,
                progressToken: progressToken,
                client: client
            )
            self.active = session
            presented = session
            return
        }

        stop()
        let session = Session(
            key: key,
            player: AVPlayer(url: url),
            duration: duration,
            progressToken: progressToken,
            client: client
        )
        active = session
        presented = session
    }

    func handleFinish(seconds: Double, percent: Int) {
        guard let active else { return }
        let token = active.progressToken
        let client = active.client
        let shouldComplete = percent >= 90

        Task {
            try? await client.reportProgress(token: token, seconds: seconds, percent: percent)
            if shouldComplete {
                try? await client.setCompleted(true, token: token)
            }
        }
    }

    func setPictureInPicture(active: Bool) {
        isPictureInPictureActive = active
    }

    /// Vuelve a presentar el player activo (restore desde PiP).
    func restore() {
        guard let active else { return }
        presented = active
    }

    func stop() {
        active?.player.pause()
        active = nil
        presented = nil
        isPictureInPictureActive = false
    }
}
