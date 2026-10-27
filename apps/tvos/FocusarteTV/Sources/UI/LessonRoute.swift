import Foundation
import FocusarteCore

/// Ruta de navegación a una lección.
///
/// `autoPlay` se activa cuando el usuario aprieta Play en el control remoto
/// sobre una fila del outline: la lección se abre y, si tiene video, arranca.
struct LessonRoute: Hashable {
    let summary: LessonSummary
    let autoPlay: Bool
    let courseSlug: String
    let courseTitle: String
    let sectionTitle: String
}
