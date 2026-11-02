import XCTest
@testable import FocusarteCore

final class LessonFocusTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func lesson(_ id: String, percent: Int) -> LessonSummary {
        LessonSummary(id: id, title: id, path: "/posts/\(id)", percentComplete: percent)
    }

    private func memory(_ id: String, age: TimeInterval) -> LessonFocusMemory {
        LessonFocusMemory(lessonID: id, updatedAt: now.addingTimeInterval(-age))
    }

    func testFreshMemoryWinsEvenIfEarlierLessonsArePending() {
        let lessons = [
            lesson("1", percent: 0),
            lesson("2", percent: 0),
            lesson("3", percent: 0)
        ]

        XCTAssertEqual(
            LessonFocus.target(in: lessons, remembered: memory("3", age: 60), now: now),
            "3"
        )
    }

    func testExpiredMemoryIsIgnored() {
        let lessons = [
            lesson("1", percent: 100),
            lesson("2", percent: 50),
            lesson("3", percent: 0)
        ]

        XCTAssertEqual(
            LessonFocus.target(in: lessons, remembered: memory("3", age: 301), now: now),
            "2"
        )
    }

    func testMemoryForUnknownLessonIsIgnored() {
        let lessons = [lesson("1", percent: 0)]

        XCTAssertEqual(
            LessonFocus.target(in: lessons, remembered: memory("removed", age: 10), now: now),
            "1"
        )
    }

    func testWithoutMemoryFocusesFirstPendingLesson() {
        let lessons = [
            lesson("1", percent: 100),
            lesson("2", percent: 0),
            lesson("3", percent: 0)
        ]

        XCTAssertEqual(
            LessonFocus.target(in: lessons, remembered: nil, now: now),
            "2"
        )
    }

    func testAllCompletedFocusesFirstLesson() {
        let lessons = [lesson("1", percent: 100), lesson("2", percent: 100)]

        XCTAssertEqual(
            LessonFocus.target(in: lessons, remembered: nil, now: now),
            "1"
        )
    }

    func testEmptySectionHasNoTarget() {
        XCTAssertNil(
            LessonFocus.target(in: [], remembered: memory("1", age: 0), now: now)
        )
    }

    func testMemoryAtExactLifetimeIsStillValid() {
        let lessons = [lesson("1", percent: 0), lesson("2", percent: 0)]

        XCTAssertEqual(
            LessonFocus.target(in: lessons, remembered: memory("2", age: 300), now: now),
            "2"
        )
    }
}
