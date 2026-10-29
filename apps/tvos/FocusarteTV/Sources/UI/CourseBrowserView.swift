import SwiftUI
import FocusarteCore

/// Un curso = una pestaña. Header con portada + intro, picker segmentado de
/// bloques y carrusel del bloque seleccionado.
struct CourseBrowserView: View {
    let course: Course

    @EnvironmentObject private var session: SessionStore
    @ObservedObject private var playback = PlaybackManager.shared

    @State private var outline: CourseOutline?
    @State private var route: LessonRoute?
    @State private var errorMessage: String?
    @State private var selectedSectionID: String = ""
    @State private var carouselTarget: String?
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
        .onChange(of: focusedLesson) { _, newValue in
            guard let newValue, let outline else { return }
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard focusedLesson == newValue else { return }
                applyPrefetchPlan(outline: outline, currentLessonID: newValue)
            }
        }
    }

    private func content(_ outline: CourseOutline) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(outline)

                Picker("Bloque", selection: sectionBinding(outline)) {
                    ForEach(outline.sections) { section in
                        Text(shortLabel(section)).tag(section.id)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if let section = selectedSection {
                    Text(section.title)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    lessonCarousel(section)
                }
            }
            .padding(.horizontal, 70)
            .padding(.vertical, 50)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(_ outline: CourseOutline) -> some View {
        HStack(alignment: .top, spacing: 28) {
            CachedImage(url: course.imageURL) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
            }
            .frame(width: 320, height: 180)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text(course.title)
                    .font(.system(size: 34, weight: .bold))

                if let intro = outline.intro, !intro.isEmpty {
                    Text(intro)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 16) {
                    ProgressView(value: Double(outline.percentComplete), total: 100)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 320)

                    Text("\(outline.completedCount) de \(outline.allLessons.count) lecciones")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
    }

    private func lessonCarousel(_ section: CourseSection) -> some View {
        ScrollViewReader { proxy in
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
            .onChange(of: carouselTarget) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - Selección

    private func sectionBinding(_ outline: CourseOutline) -> Binding<String> {
        Binding(
            get: { selectedSectionID },
            set: { newValue in
                selectedSectionID = newValue
                focusedLesson = nil
                if let section = outline.sections.first(where: { $0.id == newValue }) {
                    let first = section.lessons.first?.id ?? ""
                    carouselTarget = first
                    applyPrefetchPlan(outline: outline, currentLessonID: first)
                }
            }
        )
    }

    /// "Bloque 1 - Dos historias…" → "Bloque 1"; si no, el título corto.
    private func shortLabel(_ section: CourseSection) -> String {
        if let range = section.title.range(of: " - ") {
            let prefix = String(section.title[..<range.lowerBound])
            if prefix.lowercased().hasPrefix("bloque") {
                return prefix
            }
        }

        if section.title.count > 26 {
            return String(section.title.prefix(24)) + "…"
        }
        return section.title
    }

    private var selectedSection: CourseSection? {
        guard let outline else { return nil }
        if let section = outline.sections.first(where: { $0.id == selectedSectionID }) {
            return section
        }
        return outline.sections.first
    }

    // MARK: - Miniaturas por prioridad

    /// Actual → siguientes del bloque actual → bloque siguiente → uno atrás →
    /// resto de los siguientes → bloques anteriores.
    private func applyPrefetchPlan(outline: CourseOutline, currentLessonID: String) {
        let sections = outline.sections
        guard let currentIndex = sections.firstIndex(where: { $0.id == selectedSectionID }) else {
            return
        }

        var plan: [LessonSummary] = []
        let current = sections[currentIndex]

        if let index = current.lessons.firstIndex(where: { $0.id == currentLessonID }) {
            plan.append(contentsOf: current.lessons[index...])
            plan.append(contentsOf: current.lessons[..<index])
        } else {
            plan.append(contentsOf: current.lessons)
        }

        if currentIndex + 1 < sections.count {
            plan.append(contentsOf: sections[currentIndex + 1].lessons)
        }
        if currentIndex > 0 {
            plan.append(contentsOf: sections[currentIndex - 1].lessons)
        }
        if currentIndex + 2 < sections.count {
            for index in (currentIndex + 2)..<sections.count {
                plan.append(contentsOf: sections[index].lessons)
            }
        }
        if currentIndex >= 2 {
            for index in stride(from: currentIndex - 2, through: 0, by: -1) {
                plan.append(contentsOf: sections[index].lessons)
            }
        }

        session.prefetchPosters(ordered: plan)
    }

    // MARK: - Navegación

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
            selectedSectionID = section.id
        }

        carouselTarget = target.id
        applyPrefetchPlan(outline: outline, currentLessonID: target.id)

        // Primero se hace scroll a la tarjeta; recién después se mueve el foco.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
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
