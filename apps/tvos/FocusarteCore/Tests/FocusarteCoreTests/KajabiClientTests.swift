import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import FocusarteCore

private final class MockTransport: HTTPTransport, @unchecked Sendable {
    struct Stub {
        let status: Int
        let headers: [String: String]
        let body: Data
        let url: URL
    }

    private(set) var requests: [URLRequest] = []
    private var routes: [(method: String, path: String, stub: Stub)] = []
    private let fallback: Stub

    init(fallback: Stub) {
        self.fallback = fallback
    }

    func stub(
        _ method: String,
        _ path: String,
        status: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        let url = URL(string: "https://www.focusarte.com\(path)")!
        routes.append((method, path, Stub(status: status, headers: headers, body: body, url: url)))
    }

    func perform(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""

        for route in routes where route.method == method && route.path == path {
            return HTTPResponse(
                statusCode: route.stub.status,
                url: route.stub.url,
                headers: route.stub.headers,
                body: route.stub.body
            )
        }

        return HTTPResponse(
            statusCode: fallback.status,
            url: request.url ?? fallback.url,
            headers: fallback.headers,
            body: fallback.body
        )
    }

    func lastRequest(to path: String) -> URLRequest? {
        requests.last { $0.url?.path == path }
    }
}

final class KajabiClientTests: XCTestCase {
    private let baseURL = URL(string: "https://www.focusarte.com")!
    private let libraryPath = "/library"

    private let loginHTML = """
    <html><head><meta name="csrf-token" content="CSRF_123"></head><body>
      <form action="/login" method="post">
        <input type="hidden" name="authenticity_token" value="AUTH_123">
        <input name="member[email]">
        <input name="member[password]" type="password">
      </form>
    </body></html>
    """

    private func makeTransport() -> MockTransport {
        MockTransport(fallback: .init(status: 404, headers: [:], body: Data(), url: baseURL))
    }

    func testSignInStoresSessionAndLoadsLibrary() async throws {
        let libraryHTML = try Fixture.text("library.html")
        let transport = makeTransport()
        transport.stub("GET", "/login", body: Data(loginHTML.utf8))
        transport.stub(
            "POST",
            "/login",
            status: 302,
            headers: [
                "Location": "/library",
                "Set-Cookie": "_kjb_session=session123; path=/; HttpOnly, remember_member_token=remember123; path=/; HttpOnly"
            ]
        )
        transport.stub("GET", libraryPath, body: Data(libraryHTML.utf8))

        let client = KajabiClient(baseURL: baseURL, transport: transport)
        try await client.signIn(email: "user@example.invalid", password: "secret")

        let authenticated = await client.isAuthenticated
        XCTAssertTrue(authenticated)

        let cookies = await client.cookieSnapshot
        XCTAssertEqual(cookies["_kjb_session"], "session123")
        XCTAssertEqual(cookies["remember_member_token"], "remember123")

        let loginGET = try XCTUnwrap(
            transport.requests.first { $0.httpMethod == "GET" && $0.url?.path == "/login" }
        )
        // El GET de /login no debe llevar CSRF header (solo los POST).
        XCTAssertNil(loginGET.value(forHTTPHeaderField: "X-CSRF-Token"))

        let post = try XCTUnwrap(
            transport.requests.first { $0.httpMethod == "POST" && $0.url?.path == "/login" }
        )
        XCTAssertEqual(post.value(forHTTPHeaderField: "X-CSRF-Token"), "CSRF_123")
        // Rails rechaza con 422 si el Origin lleva barra final.
        XCTAssertEqual(post.value(forHTTPHeaderField: "Origin"), "https://www.focusarte.com")

        let body = String(data: post.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("member%5Bemail%5D=user%40example.invalid"))
        XCTAssertTrue(body.contains("authenticity_token=AUTH_123"))
        XCTAssertTrue(body.contains("member%5Bremember_me%5D=1"))

        let libraryRequest = try XCTUnwrap(transport.lastRequest(to: libraryPath))
        let cookieHeader = libraryRequest.value(forHTTPHeaderField: "Cookie") ?? ""
        XCTAssertTrue(cookieHeader.contains("_kjb_session=session123"))

        let courses = try await client.loadLibrary()
        XCTAssertEqual(courses.count, 2)
        XCTAssertEqual(courses.first?.slug, "historia-del-arte-clasico")
    }

    func testInvalidCredentialsThrowsWithServerMessage() async throws {
        let transport = makeTransport()
        transport.stub("GET", "/login", body: Data(loginHTML.utf8))
        transport.stub(
            "POST",
            "/login",
            status: 200,
            body: Data(
                "<html><body><div class=\"alert\">Inválido correo electrónico o contraseña.</div></body></html>".utf8
            )
        )

        let client = KajabiClient(baseURL: baseURL, transport: transport)

        do {
            try await client.signIn(email: "user@example.invalid", password: "bad")
            XCTFail("Debía lanzar invalidCredentials")
        } catch let KajabiError.invalidCredentials(message) {
            XCTAssertEqual(message, "Inválido correo electrónico o contraseña.")
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
    }

    func testLoginRejectionIncludesHTTPStatus() async throws {
        let transport = makeTransport()
        transport.stub("GET", "/login", body: Data(loginHTML.utf8))
        transport.stub(
            "POST",
            "/login",
            status: 422,
            body: Data("<html><body>CSRF inválido</body></html>".utf8)
        )

        let client = KajabiClient(baseURL: baseURL, transport: transport)

        do {
            try await client.signIn(email: "user@example.invalid", password: "secret")
            XCTFail("Debía lanzar invalidCredentials")
        } catch let KajabiError.invalidCredentials(message) {
            XCTAssertTrue(message.contains("HTTP 422"), "mensaje: \(message)")
            XCTAssertTrue(message.contains("sin título"), "mensaje: \(message)")
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
    }

    func testExpiredSessionIsDetected() async throws {
        let transport = makeTransport()
        transport.stub("GET", libraryPath, status: 302, headers: ["Location": "/login"])
        transport.stub("GET", "/login", body: Data(loginHTML.utf8))

        let client = KajabiClient(baseURL: baseURL, transport: transport)

        do {
            _ = try await client.loadLibrary()
            XCTFail("Debía lanzar sessionExpired")
        } catch KajabiError.sessionExpired {
            // esperado
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
    }

    func testCompletionPostsWithCSRFAndToken() async throws {
        let libraryHTML = try Fixture.text("library.html")
        let transport = makeTransport()
        transport.stub("GET", libraryPath, body: Data(libraryHTML.utf8))
        transport.stub("POST", "/tracking/completion", body: Data())

        let client = KajabiClient(baseURL: baseURL, transport: transport)
        _ = try await client.loadLibrary()

        try await client.setCompleted(true, token: "JWT_ABC")

        let post = try XCTUnwrap(transport.lastRequest(to: "/tracking/completion"))
        XCTAssertEqual(post.httpMethod, "POST")
        XCTAssertEqual(post.value(forHTTPHeaderField: "X-CSRF-Token"), "TEST_CSRF")

        let body = String(data: post.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("token=JWT_ABC"))
        XCTAssertFalse(body.contains("_method=DELETE"))

        try await client.setCompleted(false, token: "JWT_ABC")
        let posts = transport.requests.filter { $0.url?.path == "/tracking/completion" }
        let lastBody = String(data: posts.last?.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(lastBody.contains("_method=DELETE"))
        XCTAssertTrue(lastBody.contains("token=JWT_ABC"))
    }

    func testProgressIsSkippedWhenPercentIsZero() async throws {
        let transport = makeTransport()
        let client = KajabiClient(baseURL: baseURL, transport: transport)

        try await client.reportProgress(token: "JWT", seconds: 30, percent: 0)

        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testProgressSendsSecondsAndPercent() async throws {
        let libraryHTML = try Fixture.text("library.html")
        let transport = makeTransport()
        transport.stub("GET", libraryPath, body: Data(libraryHTML.utf8))
        transport.stub("POST", "/tracking/progress", body: Data())

        let client = KajabiClient(baseURL: baseURL, transport: transport)
        _ = try await client.loadLibrary()

        try await client.reportProgress(token: "JWT_ABC", seconds: 125.7, percent: 42)

        let post = try XCTUnwrap(transport.lastRequest(to: "/tracking/progress"))
        let body = String(data: post.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("progress_seconds=125"))
        XCTAssertTrue(body.contains("progress_percent=42"))
        XCTAssertEqual(post.value(forHTTPHeaderField: "X-CSRF-Token"), "TEST_CSRF")
    }
}
