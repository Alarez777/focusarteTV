import Foundation
import Combine

/// Preferencias de reproducción persistidas en UserDefaults.
@MainActor
final class PlaybackPreferences: ObservableObject {
    static let shared = PlaybackPreferences()

    private static let autoplayKey = "autoplay_next_lesson"

    @Published var autoplayNextLesson: Bool {
        didSet {
            UserDefaults.standard.set(autoplayNextLesson, forKey: Self.autoplayKey)
        }
    }

    private init() {
        if let stored = UserDefaults.standard.object(forKey: Self.autoplayKey) as? Bool {
            autoplayNextLesson = stored
        } else {
            autoplayNextLesson = true
        }
    }
}
