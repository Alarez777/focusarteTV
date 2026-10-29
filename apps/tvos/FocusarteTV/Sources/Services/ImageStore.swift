import Foundation
import UIKit

/// Cache de imágenes en dos niveles: memoria (decodificadas) y disco (URLCache).
///
/// `AsyncImage` vuelve a mostrar el placeholder en cada aparición aunque la
/// imagen esté cacheada; este store permite dibujarla en el primer frame.
final class ImageStore: @unchecked Sendable {
    static let shared = ImageStore()

    private let memory = NSCache<NSURL, UIImage>()
    private let cache: URLCache
    private let session: URLSession

    private init() {
        memory.countLimit = 300
        memory.totalCostLimit = 128 * 1024 * 1024

        cache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024
        )
        URLCache.shared = cache

        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration)
    }

    func cachedImage(for url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    /// Bytes que ocupa la cache de red (disco + memoria).
    var cacheBytes: Int {
        cache.currentDiskUsage + cache.currentMemoryUsage
    }

    func clear() {
        memory.removeAllObjects()
        cache.removeAllCachedResponses()
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cachedImage(for: url) {
            return cached
        }

        let request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 30
        )

        if let response = cache.cachedResponse(for: request),
           let image = UIImage(data: response.data) {
            memory.setObject(image, forKey: url as NSURL, cost: response.data.count)
            return image
        }

        do {
            let (data, _) = try await session.data(for: request)
            guard let image = UIImage(data: data) else { return nil }
            memory.setObject(image, forKey: url as NSURL, cost: data.count)
            return image
        } catch {
            return nil
        }
    }
}
