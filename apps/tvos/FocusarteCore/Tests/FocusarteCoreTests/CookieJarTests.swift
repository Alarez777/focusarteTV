import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import FocusarteCore

final class CookieJarTests: XCTestCase {
    private let host = URL(string: "https://www.focusarte.com")!

    private func cookie(_ name: String, _ value: String, expires: Date? = nil) -> HTTPCookie {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: "www.focusarte.com",
            .path: "/"
        ]
        if let expires {
            properties[.expires] = expires
        }
        return HTTPCookie(properties: properties)!
    }

    func testHeaderIsStableAndSorted() {
        let jar = CookieJar(["b": "2", "a": "1"])
        XCTAssertEqual(jar.header, "a=1; b=2")
        XCTAssertEqual(jar["a"], "1")
        XCTAssertFalse(jar.isEmpty)
    }

    func testAbsorbReplacesAndExpires() {
        var jar = CookieJar()
        jar.absorb([cookie("_kjb_session", "one")])
        XCTAssertEqual(jar["_kjb_session"], "one")

        jar.absorb([cookie("_kjb_session", "two")])
        XCTAssertEqual(jar["_kjb_session"], "two")

        jar.absorb([cookie("_kjb_session", "gone", expires: Date().addingTimeInterval(-60))])
        XCTAssertNil(jar["_kjb_session"])
        XCTAssertTrue(jar.isEmpty)
    }

    func testRemoveAll() {
        var jar = CookieJar(["a": "1"])
        jar.removeAll()
        XCTAssertTrue(jar.isEmpty)
        XCTAssertEqual(jar.header, "")
    }
}
