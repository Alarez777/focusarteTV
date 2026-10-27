import Foundation
import FocusarteCore

/// Ruta de navegación a una lección.
///
/// `autoPlay` se activa cuando el usuario aprieta Play en el control remoto
/// sobre una fila del outline: la lección se abre y, si tiene video, arranca.
/// `courseTitle`/`sectionTitle` viajan con la ruta para armar los metadatos del
/// reproductor.
struct LessonRoute: Hashable {
    let summary: LessonSummary
    let autoPlay: Bool
    let courseTitle: String
    let sectionTitle: String
}
