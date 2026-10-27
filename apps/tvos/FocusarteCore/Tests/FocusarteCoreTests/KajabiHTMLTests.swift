import XCTest
@testable import FocusarteCore

final class KajabiHTMLTests: XCTestCase {
    private let baseURL = URL(string: "https://www.focusarte.com")!

    func testLibraryFindsBothCourses() throws {
        let html = try Fixture.text("library.html")
        let courses = try KajabiHTML.parseLibrary(html, baseURL: baseURL)

        XCTAssertEqual(courses.count, 2)
        XCTAssertEqual(
            courses.map(\.slug),
            ["historia-del-arte-clasico", "recorridos-por-el-thyssen"]
        )
        XCTAssertEqual(courses[0].title, "Historia del Arte Clásico")
        XCTAssertEqual(courses[0].percentComplete, 46)
        XCTAssertNotNil(courses[0].imageURL)
        XCTAssertEqual(courses[0].id, "historia-del-arte-clasico")
    }

    func testCourseOutline() throws {
        let html = try Fixture.text("course.html")
        let outline = try KajabiHTML.parseCourse(html, slug: "historia-del-arte-clasico")

        XCTAssertEqual(outline.sections.count, 9)
        XCTAssertEqual(outline.allLessons.count, 97)
        XCTAssertEqual(outline.completedCount, 45)
        XCTAssertEqual(outline.percentComplete, 46)

        let firstSection = try XCTUnwrap(outline.sections.first)
        XCTAssertTrue(firstSection.title.hasPrefix("Bloque 1"))

        let firstLesson = try XCTUnwrap(outline.allLessons.first)
        XCTAssertEqual(firstLesson.title, "Bienvenida")
        XCTAssertEqual(
            firstLesson.path,
            "/products/historia-del-arte-clasico/categories/2150657000/posts/2159073161"
        )
        XCTAssertTrue(firstLesson.isCompleted)
        XCTAssertEqual(firstLesson.id, "2159073161")
    }

    func testLessonWithVideo() throws {
        let html = try Fixture.text("lesson-video.html")
        let path = "/products/historia-del-arte-clasico/categories/2150657000/posts/2159073149"
        let lesson = try KajabiHTML.parseLesson(html, path: path)

        XCTAssertEqual(lesson.id, "2159073149")
        XCTAssertEqual(lesson.title, "Usa la app, deja comentarios y cambia la foto de perfil")
        XCTAssertEqual(lesson.video?.mediaID, "03929lqadx")
        XCTAssertEqual(lesson.trackedPercent, 2)
        XCTAssertTrue(lesson.isCompleted)
        XCTAssertEqual(lesson.progressToken, "TEST_JWT")
        XCTAssertFalse(lesson.bodyHTML.isEmpty)
        XCTAssertTrue(lesson.bodyHTML.contains("Apple Store"))
        XCTAssertNotNil(lesson.nextPath)
        XCTAssertTrue(lesson.downloads.isEmpty)
    }

    func testLessonWithPDF() throws {
        let html = try Fixture.text("lesson-pdf.html")
        let path = "/products/historia-del-arte-clasico/categories/2150657000/posts/2159073410"
        let lesson = try KajabiHTML.parseLesson(html, path: path)

        XCTAssertEqual(lesson.title, "📄 PDF - Obras de Judit y Holofernes")
        XCTAssertNil(lesson.video)
        XCTAssertEqual(lesson.downloads.count, 1)
        XCTAssertEqual(
            lesson.downloads.first?.path,
            "https://www.focusarte.com/courses/downloads/2153936966/focusarte_judit_y_holofernes-pdf"
        )
        XCTAssertEqual(lesson.downloads.first?.title, "Focusarte - Judit y Holofernes")
    }

    func testPosterURLFromStillURL() throws {
        let html = #"""
        <html><body><script>
        _wq.push({"abc": JSON.parse('{\"playerColor\":\"#de3e50\",\"stillUrl\":\"https://cdn.example.com/poster.jpg\",\"autoPlay\":false}')});
        </script></body></html>
        """#

        let lesson = try KajabiHTML.parseLesson(
            html,
            path: "/products/x/categories/1/posts/2"
        )
        XCTAssertEqual(lesson.posterURL?.absoluteString, "https://cdn.example.com/poster.jpg")
    }

    func testPosterURLIsNilWithoutStillURL() throws {
        let html = try Fixture.text("lesson-video.html")
        let lesson = try KajabiHTML.parseLesson(
            html,
            path: "/products/historia-del-arte-clasico/categories/2150657000/posts/2159073149"
        )
        XCTAssertNil(lesson.posterURL)
    }

    func testCSRFToken() throws {
        let html = try Fixture.text("library.html")
        XCTAssertEqual(KajabiHTML.csrfToken(from: html), "TEST_CSRF")
    }

    func testLoginFormParsing() throws {
        let html = """
        <html><body>
        <form action="/login" method="post">
          <input type="hidden" name="authenticity_token" value="TOKEN_123">
          <input name="member[email]">
          <input name="member[password]" type="password">
        </form>
        </body></html>
        """
        XCTAssertEqual(KajabiHTML.authenticityToken(from: html), "TOKEN_123")
        XCTAssertEqual(KajabiHTML.csrfToken(from: html), "TOKEN_123")
    }

    func testLoginErrorMessage() {
        let html = """
        <html><body><div class="alert alert-danger">Inválido correo electrónico o contraseña.</div></body></html>
        """
        XCTAssertEqual(
            KajabiHTML.loginErrorMessage(from: html),
            "Inválido correo electrónico o contraseña."
        )
    }
}
