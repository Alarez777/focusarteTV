import SwiftUI
import FocusarteCore

struct CourseView: View {
    let course: Course

    @EnvironmentObject private var session: SessionStore

    @State private var outline: CourseOutline?
    @State private var errorMessage: String?
    @State private var route: LessonRoute?
    @FocusState private var focusedLesson: String?

    var body: some View {
        Group {
            if let outline {
                content(outline)
            } else if let errorMessage {
                VStack(spacing: 24) {
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
        .onChange(of: route?.summary.id) { _, newValue in
            // Al volver de una lección, refrescamos el progreso en segundo plano.
            if newValue == nil {
                Task { await refresh() }
            }
        }
        .task { await loadWithCache() }
    }

    private func content(_ outline: CourseOutline) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 50) {
                    HStack(spacing: 24) {
                        ProgressBar(percent: outline.percentComplete)
                            .frame(maxWidth: 520)

                        Text("\(outline.completedCount) de \(outline.allLessons.count) lecciones")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }

                    ForEach(outline.sections) { section in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(section.title)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))

                            ForEach(section.lessons) { lesson in
                                lessonButton(lesson)
                            }
                        }
                    }
                }
                .padding(80)
            }
            .task(id: outline.slug) {
                await focusNextLesson(in: outline, proxy: proxy)
            }
        }
        .navigationTitle(course.title)
    }

    private func lessonButton(_ lesson: LessonSummary) -> some View {
        Button {
            route = LessonRoute(summary: lesson, autoPlay: false)
        } label: {
            LessonRow(lesson: lesson)
        }
        .focused($focusedLesson, equals: lesson.id)
        .id(lesson.id)
        .onPlayPauseCommand {
            route = LessonRoute(summary: lesson, autoPlay: true)
        }
    }

    /// Al abrir el curso, el foco va a la primera lección sin completar.
    @MainActor
    private func focusNextLesson(in outline: CourseOutline, proxy: ScrollViewProxy) async {
        guard let next = outline.allLessons.first(where: { !$0.isCompleted })
            ?? outline.allLessons.first else {
            return
        }

        // Dejamos que SwiftUI termine de armar la lista antes de mover el foco.
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(next.id, anchor: .center)
        }
        try? await Task.sleep(nanoseconds: 120_000_000)
        focusedLesson = next.id
    }

    // MARK: - Datos

    @MainActor
    private func loadWithCache() async {
        if let cached = session.cachedOutline(for: course.slug) {
            outline = cached
        }
        await refresh()
    }

    @MainActor
    private func refresh() async {
        do {
            let fresh = try await session.loadOutline(slug: course.slug)
            if let current = outline, isSame(current, fresh) {
                return
            }
            outline = fresh
        } catch {
            // Con cache mostramos lo viejo; solo reportamos si no hay nada.
            if outline == nil {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
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
