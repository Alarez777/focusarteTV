import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit
import FocusarteCore

/// Dueño único del playback de la app.
///
/// Permite reutilizar el mismo `AVPlayer` cuando el usuario vuelve a elegir el
/// video que ya está reproduciendo (incluso en PiP) y presentarlo en grande en
/// lugar de crear uno nuevo. También adjunta los metadatos del video.
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
        let title: String
        let courseTitle: String
        let sectionTitle: String
        let artworkURL: URL?
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
        client: KajabiClient,
        title: String,
        courseTitle: String,
        sectionTitle: String,
        artworkURL: URL?
    ) {
        if let active, active.key == key,
           isPictureInPictureActive || active.player.timeControlStatus != .paused {
            let session = Session(
                key: key,
                player: active.player,
                duration: duration,
                progressToken: progressToken,
                client: client,
                title: title,
                courseTitle: courseTitle,
                sectionTitle: sectionTitle,
                artworkURL: artworkURL
            )
            self.active = session
            presented = session
            applyMetadata(
                to: active.player.currentItem,
                title: title,
                courseTitle: courseTitle,
                sectionTitle: sectionTitle
            )
            updateNowPlaying(
                title: title,
                courseTitle: courseTitle,
                sectionTitle: sectionTitle,
                duration: duration
            )
            loadArtwork(url: artworkURL, for: active.player.currentItem, session: session)
            return
        }

        stop()

        let item = AVPlayerItem(url: url)
        applyMetadata(to: item, title: title, courseTitle: courseTitle, sectionTitle: sectionTitle)
        let player = AVPlayer(playerItem: item)

        let session = Session(
            key: key,
            player: player,
            duration: duration,
            progressToken: progressToken,
            client: client,
            title: title,
            courseTitle: courseTitle,
            sectionTitle: sectionTitle,
            artworkURL: artworkURL
        )
        active = session
        presented = session
        updateNowPlaying(
            title: title,
            courseTitle: courseTitle,
            sectionTitle: sectionTitle,
            duration: duration
        )
        loadArtwork(url: artworkURL, for: item, session: session)
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
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Metadata

    private func applyMetadata(
        to item: AVPlayerItem?,
        title: String,
        courseTitle: String,
        sectionTitle: String
    ) {
        guard let item else { return }
        item.externalMetadata = metadataItems(
            title: title,
            courseTitle: courseTitle,
            sectionTitle: sectionTitle
        )
    }

    private func metadataItems(
        title: String,
        courseTitle: String,
        sectionTitle: String
    ) -> [AVMetadataItem] {
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = title as NSString
        titleItem.extendedLanguageTag = "und"

        let descriptionItem = AVMutableMetadataItem()
        descriptionItem.identifier = .commonIdentifierDescription
        descriptionItem.value = "\(courseTitle) · \(sectionTitle)" as NSString
        descriptionItem.extendedLanguageTag = "und"

        return [titleItem, descriptionItem]
    }

    private func updateNowPlaying(
        title: String,
        courseTitle: String,
        sectionTitle: String,
        duration: TimeInterval
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: courseTitle,
            MPMediaItemPropertyAlbumTitle: sectionTitle,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(url: URL?, for item: AVPlayerItem?, session: Session) {
        guard let url, let item else { return }

        Task {
            guard let image = await ImageStore.shared.image(for: url) else { return }

            if let data = image.jpegData(compressionQuality: 0.9) {
                let artwork = AVMutableMetadataItem()
                artwork.identifier = .commonIdentifierArtwork
                artwork.value = data as NSData
                artwork.dataType = "public.jpeg"

                var items = metadataItems(
                    title: session.title,
                    courseTitle: session.courseTitle,
                    sectionTitle: session.sectionTitle
                )
                items.append(artwork)
                item.externalMetadata = items
            }

            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                image
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
}
