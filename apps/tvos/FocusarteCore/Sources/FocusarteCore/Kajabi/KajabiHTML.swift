import Foundation
import SwiftSoup

/// Parseo del HTML server-rendered de Kajabi.
///
/// Todos los selectores viven acá: si Kajabi cambia el markup, se arregla en un
/// solo archivo y los tests lo detectan.
public enum KajabiHTML {

    // MARK: - Tokens

    public static func csrfToken(from html: String) -> String? {
        guard let doc = try? SwiftSoup.parse(html) else { return nil }

        if let meta = selectFirst(doc, "meta[name='csrf-token']") {
            let content = (try? meta.attr("content")) ?? ""
            if !content.isEmpty { return content }
        }
        if let input = selectFirst(doc, "input[name='authenticity_token']") {
            let value = (try? input.attr("value")) ?? ""
            if !value.isEmpty { return value }
        }
        return nil
    }

    public static func authenticityToken(from html: String) -> String? {
        guard let doc = try? SwiftSoup.parse(html) else { return nil }
        guard let input = selectFirst(doc, "input[name='authenticity_token']") else { return nil }
        let value = (try? input.attr("value")) ?? ""
        return value.isEmpty ? nil : value
    }

    public static func loginErrorMessage(from html: String) -> String? {
        guard let doc = try? SwiftSoup.parse(html) else { return nil }
        let selectors = [
            ".alert", ".auth__message", ".flash", ".error", ".invalid-feedback",
            "[role='alert']", "[data-error]"
        ]
        for selector in selectors {
            guard let element = selectFirst(doc, selector) else { continue }
            let message = text(element)
            if !message.isEmpty { return message }
        }
        return nil
    }

    // MARK: - Biblioteca

    public static func parseLibrary(_ html: String, baseURL: URL) throws -> [Course] {
        let doc = try document(html)
        var seen = Set<String>()
        var courses: [Course] = []

        for card in ((try? doc.select("div.product"))?.array() ?? []) {
            var href = ""
            for anchor in ((try? card.select("a"))?.array() ?? []) {
                if let candidate = try? anchor.attr("href"), candidate.hasPrefix("/products/") {
                    href = candidate
                    break
                }
            }
            guard !href.isEmpty else { continue }

            let slug = href.split(separator: "/").last.map(String.init) ?? href
            guard seen.insert(slug).inserted else { continue }

            let title = text(selectFirst(card, "h4.product__title"))

            var imageURL: URL?
            if let image = selectFirst(card, ".product__image img"),
               let src = try? image.attr("src"),
               !src.isEmpty {
                imageURL = URL(string: src, relativeTo: baseURL)?.absoluteURL
            }

            var percent = 0
            if let inner = selectFirst(card, ".progress__inner") {
                percent = percentFromWidthStyle((try? inner.attr("style")) ?? "")
            }

            courses.append(
                Course(
                    slug: slug,
                    title: title.isEmpty ? slug : title,
                    imageURL: imageURL,
                    percentComplete: percent
                )
            )
        }

        return courses
    }

    // MARK: - Curso

    public static func parseCourse(_ html: String, slug: String) throws -> CourseOutline {
        let doc = try document(html)

        let pageTitle = text(selectFirst(doc, "h1"))
        guard let outline = selectFirst(doc, "div.product-outline") else {
            throw KajabiError.parsing("no se encontró .product-outline")
        }

        var sections: [CourseSection] = []
        var currentTitle = ""
        var currentID = ""
        var currentLessons: [LessonSummary] = []

        func flush() {
            guard !currentTitle.isEmpty || !currentLessons.isEmpty else { return }
            sections.append(
                CourseSection(id: currentID, title: currentTitle, lessons: currentLessons)
            )
            currentLessons = []
        }

        for child in outline.children().array() {
            if child.hasClass("product-outline-category") {
                flush()
                currentTitle = text(child)
                var categoryHref = ""
                if let anchor = selectFirst(child, "a") {
                    categoryHref = (try? anchor.attr("href")) ?? ""
                }
                currentID = categoryHref.split(separator: "/").last.map(String.init) ?? currentTitle
                continue
            }

            let isPost = child.tagName() == "a"
                && child.hasClass("product-outline-post")
            guard isPost else { continue }

            let path = (try? child.attr("href")) ?? ""
            guard !path.isEmpty else { continue }

            let lessonTitle = text(selectFirst(child, ".media-body"))
            let id = path.split(separator: "/").last.map(String.init) ?? path

            currentLessons.append(
                LessonSummary(
                    id: id,
                    title: lessonTitle.isEmpty ? id : lessonTitle,
                    path: path,
                    percentComplete: progressPercent(in: child)
                )
            )
        }
        flush()

        return CourseOutline(
            slug: slug,
            title: pageTitle.isEmpty ? slug : pageTitle,
            sections: sections
        )
    }

    // MARK: - Lección

    public static func parseLesson(_ html: String, path: String) throws -> Lesson {
        let doc = try document(html)

        var title = text(selectFirst(doc, "h1.post-body-title"))
        if title.isEmpty {
            title = text(selectFirst(doc, "h1"))
        }

        let bodyHTML = (try? selectFirst(doc, "div.post-body")?.html()) ?? ""

        var mediaID: String?
        if let embed = selectFirst(doc, "div.wistia_embed") {
            for name in ((try? embed.classNames()) ?? []) where name.hasPrefix("wistia_async_") {
                mediaID = String(name.dropFirst("wistia_async_".count))
                break
            }
        }

        let toggle = selectFirst(doc, "[data-post-completion-toggle]")
        var token = (try? toggle?.attr("data-token")) ?? ""
        if token.isEmpty, let progress = selectFirst(doc, "[data-track-progress]") {
            token = (try? progress.attr("data-track-progress")) ?? ""
        }

        let isCompleted = ((try? toggle?.attr("data-post-completion-toggle")) ?? "") == "true"
        let trackedPercent = Int(
            (try? selectFirst(doc, "[data-tracked-percent]")?.attr("data-tracked-percent")) ?? ""
        ) ?? 0

        let downloads = ((try? doc.select("a.downloads-link"))?.array() ?? []).compactMap { anchor -> LessonDownload? in
            guard let href = try? anchor.attr("href"), !href.isEmpty else { return nil }
            let label = text(selectFirst(anchor, ".media-body"))
            return LessonDownload(title: label.isEmpty ? "Descarga" : label, path: href)
        }

        var nextPath: String?
        for anchor in ((try? doc.select(".post-actions-pagination a"))?.array() ?? []) {
            let isNext = ((try? anchor.select("i.fa-angle-right"))?.isEmpty() == false)
            if isNext, let href = try? anchor.attr("href"), !href.isEmpty {
                nextPath = href
                break
            }
        }

        let id = path.split(separator: "/").last.map(String.init) ?? path

        return Lesson(
            id: id,
            title: title.isEmpty ? id : title,
            path: path,
            bodyHTML: bodyHTML,
            video: mediaID.map { WistiaVideoRef(mediaID: $0) },
            downloads: downloads,
            progressToken: token,
            trackedPercent: min(max(trackedPercent, 0), 100),
            isCompleted: isCompleted,
            nextPath: nextPath
        )
    }

    // MARK: - Helpers

    private static func document(_ html: String) throws -> Document {
        do {
            return try SwiftSoup.parse(html)
        } catch {
            throw KajabiError.parsing("HTML inválido")
        }
    }

    private static func selectFirst(_ root: Element, _ selector: String) -> Element? {
        (try? root.select(selector))?.first()
    }

    private static func text(_ element: Element?) -> String {
        guard let element else { return "" }
        let value = (try? element.text()) ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func progressPercent(in element: Element) -> Int {
        guard let icon = selectFirst(element, ".progress-icon") else { return 0 }
        let prefix = "progress-icon-"
        for name in ((try? icon.classNames()) ?? []) where name.hasPrefix(prefix) {
            if let value = Int(name.dropFirst(prefix.count)) {
                return min(max(value, 0), 100)
            }
        }
        return 0
    }

    private static func percentFromWidthStyle(_ style: String) -> Int {
        guard let range = style.range(of: #"width:\s*([0-9]{1,3})%"#, options: .regularExpression) else {
            return 0
        }
        let digits = style[range].filter(\.isNumber)
        return Int(digits).map { min(max($0, 0), 100) } ?? 0
    }
}
