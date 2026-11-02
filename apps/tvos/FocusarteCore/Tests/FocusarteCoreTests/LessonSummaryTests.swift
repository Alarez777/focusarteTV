import XCTest
@testable import FocusarteCore

final class LessonSummaryTests: XCTestCase {
    private func lesson(percent: Int) -> LessonSummary {
        LessonSummary(
            id: "L1",
            title: "Lección",
            path: "/posts/l1",
            percentComplete: percent
        )
    }

    func testUnwatchedWhenThereIsNoProgress() {
        let summary = lesson(percent: 0)
        XCTAssertTrue(summary.isUnwatched)
        XCTAssertFalse(summary.isCompleted)
    }

    func testStartedButNotCompletedIsNotUnwatched() {
        XCTAssertFalse(lesson(percent: 1).isUnwatched)
        XCTAssertFalse(lesson(percent: 50).isUnwatched)
        XCTAssertFalse(lesson(percent: 99).isUnwatched)
    }

    func testCompletedIsNotUnwatched() {
        let summary = lesson(percent: 100)
        XCTAssertTrue(summary.isCompleted)
        XCTAssertFalse(summary.isUnwatched)
    }
}
