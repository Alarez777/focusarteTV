import XCTest
@testable import FocusarteCore

final class LessonHTMLParserTests: XCTestCase {
    private let baseURL = URL(string: "https://www.focusarte.com")!

    func testConvertsCommonBlocks() {
        let html = """
        <div class="main-content-container">
          <h1 class="post-body-title">Título</h1>
          <p>Primer párrafo con <strong>negrita</strong>.</p>
          <h2>Sección</h2>
          <ul><li>Uno</li><li>Dos</li></ul>
          <hr>
          <p><img src="/img/obra.jpg"></p>
          <blockquote>Cita</blockquote>
        </div>
        """

        let blocks = LessonHTMLParser.blocks(from: html, baseURL: baseURL)

        XCTAssertEqual(blocks.count, 6)
        XCTAssertEqual(blocks[0], .paragraph("Primer párrafo con negrita."))
        XCTAssertEqual(blocks[1], .heading(level: 2, text: "Sección"))
        XCTAssertEqual(blocks[2], .bullet(["Uno", "Dos"]))
        XCTAssertEqual(blocks[3], .divider)
        XCTAssertEqual(blocks[4], .image(URL(string: "https://www.focusarte.com/img/obra.jpg")!))
        XCTAssertEqual(blocks[5], .quote("Cita"))
    }

    func testSkipsEmptyParagraphs() {
        let html = "<p> </p><p>Texto</p>"
        let blocks = LessonHTMLParser.blocks(from: html, baseURL: baseURL)
        XCTAssertEqual(blocks, [.paragraph("Texto")])
    }

    func testRealLessonBodyProducesBlocks() throws {
        let html = try Fixture.text("lesson-video.html")
        let lesson = try KajabiHTML.parseLesson(
            html,
            path: "/products/historia-del-arte-clasico/categories/2150657000/posts/2159073149"
        )
        let blocks = LessonHTMLParser.blocks(from: lesson.bodyHTML, baseURL: baseURL)

        XCTAssertFalse(blocks.isEmpty)
        XCTAssertTrue(blocks.contains { block in
            if case .paragraph(let text) = block { return text.contains("Apple Store") }
            return false
        })
        // El título no se duplica como bloque.
        XCTAssertFalse(blocks.contains { block in
            if case .heading(_, let text) = block { return text.contains("Usa la app") }
            return false
        })
    }
}
