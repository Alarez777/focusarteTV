import SwiftUI
import FocusarteCore

struct ProgressBar: View {
    let percent: Int

    private var clamped: Int { min(max(percent, 0), 100) }

    var body: some View {
        HStack(spacing: 14) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geometry.size.width * CGFloat(clamped) / 100)
                }
            }
            .frame(height: 8)

            Text("\(clamped)%")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

struct CourseCard: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AsyncImage(url: course.imageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(course.title)
                .font(.system(size: 30, weight: .semibold))
                .lineLimit(2)

            ProgressBar(percent: course.percentComplete)
        }
    }
}

struct LessonRow: View {
    let lesson: LessonSummary

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: lesson.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(lesson.isCompleted ? Theme.accent : Color.white.opacity(0.35))

            Text(lesson.title)
                .font(.system(size: 24))
                .lineLimit(2)

            Spacer(minLength: 0)

            if lesson.percentComplete > 0 && !lesson.isCompleted {
                Text("\(lesson.percentComplete)%")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
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
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 240)
                }
            }
            .frame(maxWidth: 1200)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        case .divider:
            Divider()
                .padding(.vertical, 8)
        }
    }
}
