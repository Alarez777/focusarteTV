import Foundation

public enum LessonFocus {
    /// Primera lección sin completar (en curso o sin empezar); si el bloque
    /// ya está todo visto, la primera de la izquierda.
    public static func target(in lessons: [LessonSummary]) -> String? {
        lessons.first(where: { !$0.isCompleted })?.id ?? lessons.first?.id
    }

    /// Lección inmediatamente a la derecha de `id`. Con la lista plana del
    /// curso, cruza al bloque siguiente cuando `id` era la última del suyo.
    public static func next(after id: String, in lessons: [LessonSummary]) -> String? {
        guard let index = lessons.firstIndex(where: { $0.id == id }),
              lessons.indices.contains(index + 1) else {
            return nil
        }
        return lessons[index + 1].id
    }
}
