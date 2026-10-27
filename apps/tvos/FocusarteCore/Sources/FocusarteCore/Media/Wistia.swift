import Foundation

/// Resolución de videos de Wistia a algo que AVPlayer pueda reproducir.
public enum Wistia {
    public static func mediaJSONURL(mediaID: String) -> URL? {
        URL(string: "https://fast.wistia.com/embed/medias/\(mediaID).json")
    }

    public static func hlsURL(mediaID: String) -> URL? {
        URL(string: "https://fast.wistia.com/embed/medias/\(mediaID).m3u8")
    }

    public static func parseMedia(json data: Data, mediaID: String) throws -> VideoAsset {
        let decoded: MediaResponse
        do {
            decoded = try JSONDecoder().decode(MediaResponse.self, from: data)
        } catch {
            throw KajabiError.parsing("JSON de Wistia inválido: \(error.localizedDescription)")
        }

        let media = decoded.media
        let hls = (media.hlsEnabled ?? true) ? hlsURL(mediaID: mediaID) : nil

        let mp4Assets = media.assets.filter { $0.type.contains("mp4") }
        let candidates = mp4Assets.isEmpty
            ? media.assets.filter { $0.type == "original" }
            : mp4Assets
        let bestMP4 = candidates.max { ($0.width ?? 0) < ($1.width ?? 0) }
        let poster = media.assets.first { $0.type == "still_image" }

        return VideoAsset(
            hlsURL: hls,
            mp4Fallback: bestMP4.flatMap { URL(string: $0.url) },
            posterURL: poster.flatMap { URL(string: $0.url) },
            duration: media.duration ?? 0
        )
    }
}

private struct MediaResponse: Decodable {
    let media: Media

    struct Media: Decodable {
        let duration: Double?
        let assets: [Asset]
        let hlsEnabled: Bool?

        enum CodingKeys: String, CodingKey {
            case duration
            case assets
            case hlsEnabled = "hls_enabled"
        }
    }

    struct Asset: Decodable {
        let type: String
        let url: String
        let width: Int?
    }
}
