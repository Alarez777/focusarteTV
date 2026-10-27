import Foundation
import AVFoundation
import MediaPlayer
import FocusarteCore

struct PlaybackMetadata {
    let title: String
    let courseTitle: String
    let sectionTitle: String
    let artworkURL: URL?

    var subtitle: String {
        "\(courseTitle) · \(sectionTitle)"
    }

    func metadataItems() -> [AVMetadataItem] {
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = title as NSString
        titleItem.extendedLanguageTag = "und"

        // La línea chica de la barra de transporte.
        let subtitleItem = AVMutableMetadataItem()
        subtitleItem.identifier = .iTunesMetadataTrackSubTitle
        subtitleItem.value = subtitle as NSString
        subtitleItem.extendedLanguageTag = "und"

        let descriptionItem = AVMutableMetadataItem()
        descriptionItem.identifier = .commonIdentifierDescription
        descriptionItem.value = "\(title)\n\(courseTitle)\n\(sectionTitle)" as NSString
        descriptionItem.extendedLanguageTag = "und"

        return [titleItem, subtitleItem, descriptionItem]
    }

    func nowPlayingInfo(duration: TimeInterval) -> [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: courseTitle,
            MPMediaItemPropertyAlbumTitle: sectionTitle,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        return info
    }

    func attachArtwork(to item: AVPlayerItem) {
        guard let artworkURL else { return }
        let baseItems = metadataItems()

        Task {
            guard let image = await ImageStore.shared.image(for: artworkURL) else { return }
            guard let data = image.jpegData(compressionQuality: 0.9) else { return }

            let artwork = AVMutableMetadataItem()
            artwork.identifier = .commonIdentifierArtwork
            artwork.value = data as NSData
            artwork.dataType = "public.jpeg"
            artwork.extendedLanguageTag = "und"

            var items = baseItems
            items.append(artwork)
            item.externalMetadata = items

            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                image
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
}

/// Próxima lección reproducible que ofrece la tarjeta Up Next.
struct UpNextLesson {
    let key: String
    let url: URL
    let duration: TimeInterval
    let progressToken: String
    let client: KajabiClient
    let metadata: PlaybackMetadata
}
