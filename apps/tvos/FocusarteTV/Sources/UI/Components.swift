import SwiftUI
import FocusarteCore

/// Tarjeta del carrusel de lecciones.
struct LessonCard: View {
    let lesson: LessonSummary
    let posterURL: URL?
    var isFocused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                CachedImage(url: posterURL) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                }
                .frame(width: 360, height: 202)
                .overlay(alignment: .bottom) {
                    if !lesson.isCompleted, lesson.percentComplete > 0 {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.black.opacity(0.45))
                                Rectangle()
                                    .fill(Theme.accent)
                                    .frame(
                                        width: geometry.size.width
                                            * CGFloat(min(max(lesson.percentComplete, 0), 100)) / 100
                                    )
                            }
                        }
                        .frame(height: 9)
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if lesson.isCompleted {
                    ZStack {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 32, height: 32)
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(10)
                }
            }

            MarqueeText(
                text: lesson.title,
                font: .system(size: 20, weight: .medium),
                color: .white,
                availableWidth: 350,
                isActive: isFocused
            )
            .padding(.leading, 10)
        }
        .frame(width: 360, alignment: .leading)
    }
}

struct LessonBlockView: View {
    let block: LessonBlock

    var body: some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(.system(size: level <= 2 ? 40 : 32, weight: .bold))
                .padding(.top, 10)

        case .paragraph(let text):
            Text(text)
                .font(.system(size: 24))
                .lineSpacing(6)
                .foregroundStyle(.white.opacity(0.85))

        case .bullet(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(items.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 12) {
                        Text("•")
                        Text(items[index])
                    }
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.85))
                }
            }

        case .quote(let text):
            Text(text)
                .font(.system(size: 24, design: .serif))
                .italic()
                .padding(.leading, 22)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: 4)
                }

        case .image(let url):
            CachedImage(url: url) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 240)
            }
            .frame(maxWidth: 1200)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        case .divider:
            Divider()
                .padding(.vertical, 8)
        }
    }
}
