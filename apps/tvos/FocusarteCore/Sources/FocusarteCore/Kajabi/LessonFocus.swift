import Foundation

/// Última tarjeta enfocada dentro de un bloque.
public struct LessonFocusMemory: Equatable, Sendable {
    public let lessonID: String
    public let updatedAt: Date

    public init(lessonID: String, updatedAt: Date = .now) {
        self.lessonID = lessonID
        self.updatedAt = updatedAt
    }
}

public enum LessonFocus {
    /// Cuánto dura la memoria de la última tarjeta enfocada.
    public static let memoryLifetime: TimeInterval = 300

    /// Tarjeta que debe recibir el foco al entrar a un bloque.
    ///
    /// Si hay una posición recordada reciente y sigue existiendo, se respeta.
    /// Si no, se elige la primera lección sin completar; si todas están
    /// completas, la primera del bloque. Devuelve `nil` si el bloque está vacío.
    public static func target(
        in lessons: [LessonSummary],
        remembered: LessonFocusMemory?,
        now: Date = .now,
        maxAge: TimeInterval = memoryLifetime
    ) -> String? {
        if let remembered,
           now.timeIntervalSince(remembered.updatedAt) <= maxAge,
           lessons.contains(where: { $0.id == remembered.lessonID }) {
            return remembered.lessonID
        }

        return lessons.first(where: { !$0.isCompleted })?.id ?? lessons.first?.id
    }
}
