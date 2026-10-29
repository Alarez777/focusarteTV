import SwiftUI
import FocusarteCore

/// Un curso = una pestaña. Dentro, una shelf por bloque (patrón nativo de tvOS).
struct CourseBrowserView: View {
    let course: Course

    @EnvironmentObject private var session: SessionStore
    @ObservedObject private var playback = PlaybackManager.shared

    @State private var outline: CourseOutline?
    @State private var route: LessonRoute?
    @State private var errorMessage: String?
    @State private var scrollTarget: String?
    @FocusState private var focusedLesson: String?

    var body: some View {
        NavigationStack {
            Group {
                if let outline {
                    content(outline)
                } else if let errorMessage {
                    VStack(spacing: 20) {
                        Text(errorMessage)
                        Button("Reintentar") { Task { await refresh() } }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationDestination(item: $route) { route in
                LessonView(route: route)
            }
        }
        .task { await loadWithCache() }
        .onChange(of: playback.progressRevision) { _, _ in
            Task { await refresh() }
        }
        .onChange(of: route?.summary.id) { _, newValue in
            guard newValue == nil else { return }
            Task { await afterReturn() }
        }
    }

    private func content(_ outline: CourseOutline) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 44) {
                    progressLine(outline)

                    ForEach(outline.sections) { section in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(section.title)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))

                            lessonShelf(section)
                        }
                        .id(section.id)
                    }
                }
                .padding(.horizontal, 70)
                .padding(.vertical, 50)
            }
            .onChange(of: scrollTarget) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func progressLine(_ outline: CourseOutline) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(outline.percentComplete), total: 100)
                .progressViewStyle(.linear)
                .frame(maxWidth: 360)

            Text("\(outline.completedCount) de \(outline.allLessons.count) lecciones")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        }
    }

    private func lessonShelf(_ section: CourseSection) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 24) {
                ForEach(section.lessons) { lesson in
                    Button {
                        open(lesson, section: section, autoPlay: false)
                    } label: {
                        LessonCard(
                            lesson: lesson,
                            posterURL: session.lessonPosterURL(for: lesson.id) ?? course.imageURL
                        )
                    }
                    .buttonStyle(.card)
                    .focused($focusedLesson, equals: lesson.id)
                    .id(lesson.id)
                    .onPlayPauseCommand {
                        open(lesson, section: section, autoPlay: true)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
        .task {
            await session.prefetchPosters(for: section.lessons)
        }
    }

    private func open(_ lesson: LessonSummary, section: CourseSection, autoPlay: Bool) {
        route = LessonRoute(
            summary: lesson,
            autoPlay: autoPlay,
            courseSlug: course.slug,
            courseTitle: course.title,
            sectionTitle: section.title
        )
    }

    // MARK: - Carga y foco

    private func loadWithCache() async {
        if let cached = session.cachedOutline(for: course.slug) {
            outline = cached
            configureFocus()
        }
        await refresh()
    }

    @MainActor
    private func refresh() async {
        let hadOutline = outline != nil

        do {
            let fresh = try await session.loadOutline(slug: course.slug)
            if let current = outline, isSame(current, fresh) {
                return
            }
            outline = fresh
            if !hadOutline {
                configureFocus()
            }
        } catch {
            if outline == nil {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func afterReturn() async {
        await refresh()
        configureFocus(preferring: playback.currentLessonKey)
    }

    @MainActor
    private func configureFocus(preferring key: String? = nil) {
        guard let outline else { return }

        let target: LessonSummary?
        if let key, let match = outline.allLessons.first(where: { $0.id == key }) {
            target = match
        } else {
            target = outline.allLessons.first(where: { !$0.isCompleted })
                ?? outline.allLessons.first
        }

        guard let target else { return }

        if let section = outline.sections.first(where: { section in
            section.lessons.contains { $0.id == target.id }
        }) {
            scrollTarget = section.id
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            focusedLesson = target.id
        }
    }

    private func isSame(_ a: CourseOutline, _ b: CourseOutline) -> Bool {
        guard a.title == b.title, a.sections.count == b.sections.count else { return false }
        let left = a.allLessons
        let right = b.allLessons
        guard left.count == right.count else { return false }
        return zip(left, right).allSatisfy {
            $0.id == $1.id && $0.title == $1.title && $0.percentComplete == $1.percentComplete
        }
    }
}
