import SwiftUI
import UIKit

/// Imagen con cache que se dibuja desde el primer frame si ya está en memoria.
struct CachedImage<Placeholder: View>: View {
    let url: URL?
    let contentMode: ContentMode

    @ViewBuilder private let placeholder: () -> Placeholder
    @State private var image: UIImage?

    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
        _image = State(initialValue: url.flatMap { ImageStore.shared.cachedImage(for: $0) })
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let loaded = await ImageStore.shared.image(for: url) {
                image = loaded
            }
        }
    }
}
