import Foundation
import FocusarteCore

/// Ruta de navegación a una lección.
struct LessonRoute: Hashable {
    let summary: LessonSummary
    let courseSlug: String
    let courseTitle: String
    let sectionTitle: String
}
