import XCTest
@testable import MetroCore

final class TimetablePresentationTests: XCTestCase {
    func testCombinedRegularTableIsHiddenOnlyWhenBothDaysMatch() throws {
        let work = try record("work", day: "工作日")
        let rest = try record("rest", day: "休息日")
        let combined = try record("combined", day: "平日和周末", label: "全程")
        XCTAssertEqual(TimetablePresentation.rows([combined, rest, work]).map(\.id), ["work", "rest"])
        XCTAssertEqual(TimetablePresentation.rows([work, combined]).count, 2)
        let changed = try record("changed", day: "休息日", first: "06:11")
        XCTAssertEqual(TimetablePresentation.rows([work, changed, combined]).count, 3)
    }

    func testUnknownDaysAndShortTurnKeepTheirMeaning() throws {
        let unknown = try record("unknown", day: "来源未注明适用日", label: "全程")
        let half = try record("half", day: "平日和周末", label: "半程加班车", first: nil, last: "00:17", offset: 1, destination: "龙华")
        let work = try record("work", day: "工作日")
        let rows = TimetablePresentation.rows([half, unknown, work])
        XCTAssertEqual(rows.map(\.id), ["work", "unknown", "half"])
        XCTAssertEqual(TimetablePresentation.dayLabel(unknown), "适用日未注明")
        XCTAssertEqual(rows.last?.last?.display, "次日 00:17")
        XCTAssertEqual(rows.last?.lastDestination, "龙华")
    }

    func testEffectiveDatesPreventCollapsingDifferentPeriods() throws {
        let records = [try record("work", day: "工作日"), try record("rest", day: "休息日"),
                       try record("new", day: "平日和周末", label: "全程", from: "2026-10-01")]
        XCTAssertEqual(TimetablePresentation.rows(records).count, 3)
    }

    private func record(_ id: String, day: String, label: String? = nil, first: String? = "06:10",
                        last: String = "23:10", offset: Int = 0, destination: String? = nil,
                        from: String? = nil) throws -> Timetable {
        Timetable(id: id, lineID: "l4", direction: "福田口岸", serviceDays: day, validFrom: from,
                  validThrough: nil, first: try first.map { try ServiceTime(clock: $0, dayOffset: 0) },
                  last: try ServiceTime(clock: last, dayOffset: offset), serviceLabel: label, verifiedAt: nil,
                  lastDestination: destination, note: nil, sourceIDs: ["source"], updatedAt: "2026-09-28")
    }
}
