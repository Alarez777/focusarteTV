import SwiftUI
import FocusarteCore

struct CourseView: View {
    let course: Course

    @EnvironmentObject private var session: SessionStore

    @State private var outline: CourseOutline?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let outline {
                content(outline)
            } else if let errorMessage {
                VStack(spacing: 24) {
                    Text(errorMessage)
                    Button("Reintentar") { Task { await load() } }
                }
            } else {
                ProgressView()
            }
        }
        .navigationDestination(for: LessonSummary.self) { lesson in
            LessonView(summary: lesson)
        }
        .navigationDestination(for: LessonDownload.self) { download in
            DownloadView(download: download)
        }
        .task { await load() }
    }

    private func content(_ outline: CourseOutline) -> some View {
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
                            NavigationLink(value: lesson) {
                                LessonRow(lesson: lesson)
                            }
                        }
                    }
                }
            }
            .padding(80)
        }
        .navigationTitle(course.title)
    }

    private func load() async {
        do {
            outline = try await session.client.loadCourse(slug: course.slug)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
