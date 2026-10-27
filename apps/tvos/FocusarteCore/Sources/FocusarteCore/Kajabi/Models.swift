import Foundation

public struct Course: Identifiable, Hashable, Sendable {
    public let slug: String
    public let title: String
    public let imageURL: URL?
    public let percentComplete: Int

    public var id: String { slug }

    public init(slug: String, title: String, imageURL: URL? = nil, percentComplete: Int = 0) {
        self.slug = slug
        self.title = title
        self.imageURL = imageURL
        self.percentComplete = percentComplete
    }
}

public struct CourseSection: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let lessons: [LessonSummary]

    public init(id: String, title: String, lessons: [LessonSummary]) {
        self.id = id
        self.title = title
        self.lessons = lessons
    }
}

public struct LessonSummary: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    /// Path relativo, ej. `/products/…/categories/…/posts/…`
    public let path: String
    /// 0-100 según lo que reporta Kajabi en el outline.
    public let percentComplete: Int

    public var isCompleted: Bool { percentComplete >= 100 }

    public init(id: String, title: String, path: String, percentComplete: Int) {
        self.id = id
        self.title = title
        self.path = path
        self.percentComplete = percentComplete
    }
}

public struct CourseOutline: Sendable {
    public let slug: String
    public let title: String
    public let sections: [CourseSection]

    public init(slug: String, title: String, sections: [CourseSection]) {
        self.slug = slug
        self.title = title
        self.sections = sections
    }

    public var allLessons: [LessonSummary] {
        sections.flatMap(\.lessons)
    }

    public var completedCount: Int {
        allLessons.filter(\.isCompleted).count
    }

    public var percentComplete: Int {
        let lessons = allLessons
        guard !lessons.isEmpty else { return 0 }
        let total = lessons.reduce(0) { $0 + min($1.percentComplete, 100) }
        return total / lessons.count
    }
}

public struct WistiaVideoRef: Hashable, Sendable {
    public let mediaID: String

    public init(mediaID: String) {
        self.mediaID = mediaID
    }
}

public struct LessonDownload: Identifiable, Hashable, Sendable {
    public let title: String
    public let path: String

    public var id: String { path }

    public init(title: String, path: String) {
        self.title = title
        self.path = path
    }
}

public struct Lesson: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let path: String
    /// HTML del cuerpo de la lección (se renderiza nativo en tvOS).
    public let bodyHTML: String
    public let video: WistiaVideoRef?
    /// Miniatura que Focusarte configura para el player en la web (`stillUrl`).
    public let posterURL: URL?
    public let downloads: [LessonDownload]
    /// JWT firmado que Kajabi usa para reportar progreso de esta lección.
    public let progressToken: String
    /// Porcentaje visto según el servidor.
    public let trackedPercent: Int
    public let isCompleted: Bool
    public let nextPath: String?

    public init(
        id: String,
        title: String,
        path: String,
        bodyHTML: String,
        video: WistiaVideoRef?,
        posterURL: URL?,
        downloads: [LessonDownload],
        progressToken: String,
        trackedPercent: Int,
        isCompleted: Bool,
        nextPath: String?
    ) {
        self.id = id
        self.title = title
        self.path = path
        self.bodyHTML = bodyHTML
        self.video = video
        self.posterURL = posterURL
        self.downloads = downloads
        self.progressToken = progressToken
        self.trackedPercent = trackedPercent
        self.isCompleted = isCompleted
        self.nextPath = nextPath
    }
}

public struct VideoAsset: Sendable, Equatable {
    public let hlsURL: URL?
    public let mp4Fallback: URL?
    public let posterURL: URL?
    public let duration: TimeInterval

    public init(hlsURL: URL?, mp4Fallback: URL?, posterURL: URL?, duration: TimeInterval) {
        self.hlsURL = hlsURL
        self.mp4Fallback = mp4Fallback
        self.posterURL = posterURL
        self.duration = duration
    }

    /// URL preferida para AVPlayer.
    public var playbackURL: URL? {
        hlsURL ?? mp4Fallback
    }
}
