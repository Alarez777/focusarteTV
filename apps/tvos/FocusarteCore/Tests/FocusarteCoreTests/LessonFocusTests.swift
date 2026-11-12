import XCTest
@testable import FocusarteCore

final class LessonFocusTests: XCTestCase {
    private func lesson(_ id: String, percent: Int) -> LessonSummary {
        LessonSummary(id: id, title: id, path: "/posts/\(id)", percentComplete: percent)
    }

    func testChoosesFirstPendingLesson() {
        let lessons = [
            lesson("1", percent: 100),
            lesson("2", percent: 0),
            lesson("3", percent: 0)
        ]

        XCTAssertEqual(LessonFocus.target(in: lessons), "2")
    }

    func testChoosesInProgressLessonBeforeUnwatched() {
        let lessons = [
            lesson("1", percent: 100),
            lesson("2", percent: 40),
            lesson("3", percent: 0)
        ]

        XCTAssertEqual(LessonFocus.target(in: lessons), "2")
    }

    func testChoosesFirstLessonWhenAllCompleted() {
        let lessons = [lesson("1", percent: 100), lesson("2", percent: 100)]

        XCTAssertEqual(LessonFocus.target(in: lessons), "1")
    }

    func testEmptySectionHasNoTarget() {
        XCTAssertNil(LessonFocus.target(in: []))
    }

    func testNextLessonToTheRight() {
        let lessons = [lesson("1", percent: 100), lesson("2", percent: 0), lesson("3", percent: 0)]

        XCTAssertEqual(LessonFocus.next(after: "2", in: lessons), "3")
    }

    func testNextLessonCrossesIntoTheFollowingSectionWithTheFlattenedCourse() {
        let blockOne = [lesson("1", percent: 100), lesson("2", percent: 100)]
        let blockTwo = [lesson("3", percent: 0), lesson("4", percent: 0)]

        XCTAssertEqual(LessonFocus.next(after: "2", in: blockOne + blockTwo), "3")
    }

    func testNextLessonIsNilAtTheEndOrWhenMissing() {
        let lessons = [lesson("1", percent: 100), lesson("2", percent: 0)]

        XCTAssertNil(LessonFocus.next(after: "2", in: lessons))
        XCTAssertNil(LessonFocus.next(after: "missing", in: lessons))
    }
}
