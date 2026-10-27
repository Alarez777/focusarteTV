import Foundation
import SwiftSoup

/// Bloque de contenido de una lección, ya independiente del HTML.
public enum LessonBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet([String])
    case quote(String)
    case image(URL)
    case divider
}

/// Convierte el HTML de una lección al subconjunto que la app sabe dibujar.
///
/// tvOS no incluye WebKit, así que no hay `WKWebView` ni
/// `NSAttributedString(html:)`: este parser es el reemplazo.
public enum LessonHTMLParser {
    public static func blocks(from html: String, baseURL: URL) -> [LessonBlock] {
        guard let doc = try? SwiftSoup.parseBodyFragment(html) else { return [] }
        guard let body = doc.body() else { return [] }

        var blocks: [LessonBlock] = []
        walk(body, into: &blocks, baseURL: baseURL)
        return blocks
    }

    private static func walk(_ element: Element, into blocks: inout [LessonBlock], baseURL: URL) {
        for child in element.children().array() {
            if (try? child.hasClass("post-body-title")) == true { continue }
            if (try? child.hasClass("audio")) == true { continue }

            let tag = child.tagName().lowercased()
            switch tag {
            case "h1", "h2", "h3", "h4", "h5":
                let text = plainText(child)
                if !text.isEmpty {
                    blocks.append(.heading(level: Int(tag.dropFirst()) ?? 2, text: text))
                }

            case "p":
                if let image = imageURL(in: child, baseURL: baseURL), plainText(child).isEmpty {
                    blocks.append(.image(image))
                } else {
                    let text = plainText(child)
                    if !text.isEmpty { blocks.append(.paragraph(text)) }
                }

            case "ul", "ol":
                let items = ((try? child.select("li"))?.array() ?? [])
                    .map(plainText)
                    .filter { !$0.isEmpty }
                if !items.isEmpty { blocks.append(.bullet(items)) }

            case "img":
                if let url = imageURL(in: child, baseURL: baseURL) {
                    blocks.append(.image(url))
                }

            case "hr":
                blocks.append(.divider)

            case "blockquote":
                let text = plainText(child)
                if !text.isEmpty { blocks.append(.quote(text)) }

            case "div", "section", "article", "center", "figure":
                walk(child, into: &blocks, baseURL: baseURL)

            default:
                let text = plainText(child)
                if !text.isEmpty { blocks.append(.paragraph(text)) }
            }
        }
    }

    private static func plainText(_ element: Element) -> String {
        let raw = (try? element.text()) ?? ""
        return raw
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func imageURL(in element: Element, baseURL: URL) -> URL? {
        guard let img = (try? element.select("img"))?.first() else { return nil }
        guard let src = try? img.attr("src"), !src.isEmpty else { return nil }
        return URL(string: src, relativeTo: baseURL)?.absoluteURL
    }
}
