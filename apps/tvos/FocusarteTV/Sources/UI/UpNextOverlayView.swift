import SwiftUI

/// Tarjeta de "Up Next" en los últimos segundos del video.
/// Es solo informativa: los botones accionables son los `contextualActions`
/// nativos del player (Cancelar / Siguiente).
struct UpNextOverlayView: View {
    let next: UpNextLesson
    let countdown: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            CachedImage(url: next.metadata.artworkURL) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
            }
            .frame(width: 320, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text(label)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .textCase(.uppercase)

                Text(next.metadata.title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(next.metadata.subtitle)
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            .frame(maxWidth: 560, alignment: .leading)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.trailing, 80)
        .padding(.bottom, 200)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .allowsHitTesting(false)
    }

    private var label: String {
        if let countdown {
            return "Siguiente en \(max(countdown, 0)) s"
        }
        return "Siguiente"
    }
}
