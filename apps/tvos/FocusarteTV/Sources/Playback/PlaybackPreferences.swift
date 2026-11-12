import Foundation
import Combine

/// Preferencias de reproducción persistidas en UserDefaults.
@MainActor
final class PlaybackPreferences: ObservableObject {
    static let shared = PlaybackPreferences()

    private static let autoplayKey = "autoplay_next_lesson"
    private static let lastCourseKey = "last_course_slug"

    @Published var autoplayNextLesson: Bool {
        didSet {
            UserDefaults.standard.set(autoplayNextLesson, forKey: Self.autoplayKey)
        }
    }

    /// Último curso visitado, para abrir la app en su pestaña.
    private(set) var lastCourseSlug: String?

    private init() {
        if let stored = UserDefaults.standard.object(forKey: Self.autoplayKey) as? Bool {
            autoplayNextLesson = stored
        } else {
            autoplayNextLesson = true
        }

        lastCourseSlug = UserDefaults.standard.string(forKey: Self.lastCourseKey)
    }

    func remember(courseSlug: String) {
        lastCourseSlug = courseSlug
        UserDefaults.standard.set(courseSlug, forKey: Self.lastCourseKey)
    }

    /// Vuelve a los valores por defecto, como si la app se abriera por primera vez.
    func reset() {
        UserDefaults.standard.removeObject(forKey: Self.autoplayKey)
        UserDefaults.standard.removeObject(forKey: Self.lastCourseKey)
        // Valor heredado de versiones anteriores, ya no se usa.
        UserDefaults.standard.removeObject(forKey: "last_lesson_id")
        autoplayNextLesson = true
        lastCourseSlug = nil
    }
}
