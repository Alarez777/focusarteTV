import Foundation
import Combine

/// Preferencias de reproducción persistidas en UserDefaults.
@MainActor
final class PlaybackPreferences: ObservableObject {
    static let shared = PlaybackPreferences()

    private static let autoplayKey = "autoplay_next_lesson"
    private static let lastCourseKey = "last_course_slug"
    private static let lastLessonKey = "last_lesson_id"

    @Published var autoplayNextLesson: Bool {
        didSet {
            UserDefaults.standard.set(autoplayNextLesson, forKey: Self.autoplayKey)
        }
    }

    /// Último video reproducido, para abrir la app en su pestaña/bloque/capítulo.
    private(set) var lastCourseSlug: String?
    private(set) var lastLessonID: String?

    private init() {
        if let stored = UserDefaults.standard.object(forKey: Self.autoplayKey) as? Bool {
            autoplayNextLesson = stored
        } else {
            autoplayNextLesson = true
        }

        lastCourseSlug = UserDefaults.standard.string(forKey: Self.lastCourseKey)
        lastLessonID = UserDefaults.standard.string(forKey: Self.lastLessonKey)
    }

    func remember(courseSlug: String, lessonID: String) {
        lastCourseSlug = courseSlug
        lastLessonID = lessonID
        UserDefaults.standard.set(courseSlug, forKey: Self.lastCourseKey)
        UserDefaults.standard.set(lessonID, forKey: Self.lastLessonKey)
    }
}
