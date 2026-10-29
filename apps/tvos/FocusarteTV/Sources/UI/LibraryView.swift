import SwiftUI
import FocusarteCore

/// Navegador de cursos: pestañas de curso, pestañas de bloque y carrusel de
/// lecciones con miniatura, título y check de vista.
struct LibraryView: View {
    @EnvironmentObject private var session: SessionStore
    @ObservedObject private var playback = PlaybackManager.shared

    @State private var selectedCourseSlug: String?
    @State private var outline: CourseOutline?
    @State private var selectedSectionID: String?
    @State private var route: LessonRoute?
    @State private var errorMessage: String?
    @FocusState private var focusedLesson: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    courseTabs
                    progressLine
                    content
                }
                .padding(.horizontal, 70)
                .padding(.vertical, 50)
            }
            .navigationDestination(item: $route) { route in
                LessonView(route: route)
            }
        }
        .task { await initialLoad() }
        .onChange(of: route?.summary.id) { _, newValue in
            guard newValue == nil else { return }
            Task { await afterReturn() }
        }
        .onChange(of: playback.progressRevision) { _, _ in
            Task { await refreshOutline() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Mis Cursos")
                .font(.system(size: 52, weight: .bold))

            Spacer()

            if !session.signedInEmail.isEmpty {
                Text(session.signedInEmail)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var courseTabs: some View {
        HStack(spacing: 16) {
            ForEach(session.courses) { course in
                Button {
                    selectCourse(course.slug)
                } label: {
                    Text(course.title)
                        .font(.system(size: 22, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(
                                course.slug == selectedCourseSlug
                                    ? Theme.accent
                                    : Color.white.opacity(0.08)
                            )
                        )
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var progressLine: some View {
        if let outline {
            HStack(spacing: 20) {
                ProgressBar(percent: outline.percentComplete)
                    .frame(maxWidth: 420)

                Text("\(outline.completedCount) de \(outline.allLessons.count) lecciones")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        if let outline, let section = selectedSection {
            VStack(alignment: .leading, spacing: 22) {
                blockTabs(outline)
                lessonCarousel(section)
            }
            .task(id: prefetchKey) {
                await session.prefetchPosters(for: section.lessons)
            }
        } else if let errorMessage {
            VStack(spacing: 20) {
                Text(errorMessage)
                Button("Reintentar") { Task { await refreshOutline() } }
            }
        } else {
            ProgressView()
                .padding(.top, 60)
        }
    }

    private func blockTabs(_ outline: CourseOutline) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(outline.sections) { section in
                    Button {
                        selectedSectionID = section.id
                        focusFirst(in: section)
                    } label: {
                        Text(section.title)
                            .font(.system(size: 19, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .background(
                                Capsule().fill(
                                    section.id == selectedSection?.id
                                        ? Theme.accent
                                        : Color.white.opacity(0.08)
                                )
                            )
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func lessonCarousel(_ section: CourseSection) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 26) {
                    ForEach(section.lessons) { lesson in
                        Button {
                            open(lesson, section: section, autoPlay: false)
                        } label: {
                            LessonCard(
                                lesson: lesson,
                                posterURL: session.lessonPosterURL(for: lesson.id)
                                    ?? selectedCourse?.imageURL
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
                .padding(.vertical, 16)
                .padding(.horizontal, 8)
            }
            .onChange(of: focusedLesson) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - Selección

    private var selectedCourse: Course? {
        if let slug = selectedCourseSlug {
            return session.courses.first { $0.slug == slug }
        }
        return session.courses.first
    }

    private var selectedSection: CourseSection? {
        guard let outline else { return nil }
        if let id = selectedSectionID,
           let section = outline.sections.first(where: { $0.id == id }) {
            return section
        }
        return outline.sections.first
    }

    private var prefetchKey: String {
        guard let section = selectedSection else { return "" }
        return section.id + ":" + section.lessons.map(\.id).joined(separator: ",")
    }

    private func selectCourse(_ slug: String) {
        guard slug != selectedCourseSlug else { return }
        selectedCourseSlug = slug
        selectedSectionID = nil
        outline = session.cachedOutline(for: slug)
        configureSelection()
        Task { await refreshOutline() }
    }

    private func open(_ lesson: LessonSummary, section: CourseSection, autoPlay: Bool) {
        guard let course = selectedCourse else { return }
        route = LessonRoute(
            summary: lesson,
            autoPlay: autoPlay,
            courseSlug: course.slug,
            courseTitle: course.title,
            sectionTitle: section.title
        )
    }

    @MainActor
    private func focusFirst(in section: CourseSection) {
        let target = section.lessons.first(where: { !$0.isCompleted }) ?? section.lessons.first
        if let target {
            focusLesson(target.id)
        }
    }

    private func focusLesson(_ id: String) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            focusedLesson = id
        }
    }

    // MARK: - Carga

    private func initialLoad() async {
        guard selectedCourseSlug == nil, let first = session.courses.first else { return }
        selectedCourseSlug = first.slug
        outline = session.cachedOutline(for: first.slug)
        configureSelection()
        await refreshOutline()
    }

    @MainActor
    private func configureSelection(focusPreferring key: String? = nil) {
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
            selectedSectionID = section.id
        }

        focusLesson(target.id)
    }

    private func afterReturn() async {
        await refreshOutline()
        configureSelection(focusPreferring: playback.currentLessonKey)
    }

    @MainActor
    private func refreshOutline() async {
        guard let slug = selectedCourseSlug else { return }
        let hadOutline = outline != nil

        do {
            let fresh = try await session.loadOutline(slug: slug)
            if let current = outline, isSame(current, fresh) {
                return
            }

            outline = fresh

            if let id = selectedSectionID, !fresh.sections.contains(where: { $0.id == id }) {
                selectedSectionID = fresh.sections.first?.id
            }
            if !hadOutline {
                configureSelection()
            }
        } catch {
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
