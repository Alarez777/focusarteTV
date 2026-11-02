import Foundation

public enum LessonFocus {
    /// Primera lección sin completar (en curso o sin empezar); si el bloque
    /// ya está todo visto, la primera de la izquierda.
    public static func target(in lessons: [LessonSummary]) -> String? {
        lessons.first(where: { !$0.isCompleted })?.id ?? lessons.first?.id
    }
}
