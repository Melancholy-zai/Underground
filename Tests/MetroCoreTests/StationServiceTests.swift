import CryptoKit
import XCTest
@testable import MetroCore

final class StationServiceTests: XCTestCase {
    func testV1WithoutNewFieldsRemainsCompatible() throws {
        var json = try fixture()
        try setServices(&json, version: 1)
        let repository = try decode(json)
        let station = try XCTUnwrap(repository.station("baoti"))
        XCTAssertNil(station.serviceReview)
        XCTAssertNil(station.serviceNotices)
        XCTAssertNil(station.timetables.first?.verifiedAt)
        XCTAssertNil(station.timetables.first?.serviceLabel)
        XCTAssertEqual(station.timetables.first?.validFrom, "2026-09-01")
        XCTAssertNil(repository.pack.sources.first?.sourcePublishedAt)
    }

    func testV1RetainsRequiredStartDateAndExitDescription() throws {
        for target in ["validFrom", "description"] {
            var json = try fixture()
            try setServices(&json, version: 1)
            try mutateStation(&json) { station in
                let arrayKey = target == "validFrom" ? "timetables" : "exits"
                var records = station[arrayKey] as! [[String: Any]]
                records[0][target] = NSNull()
                station[arrayKey] = records
            }
            XCTAssertThrowsError(try decode(json), target)
        }
    }

    func testV2PreservesUnknownDatesPartialTimesAndIndependentReview() throws {
        var json = try fixture()
        try setServices(&json, version: 2)
        try mutateStation(&json) { station in
            station["serviceReview"] = ["timetableStatus": "reviewed", "exitStatus": "partial",
                                        "verifiedAt": "2026-09-28", "timetableNote": "按来源核对", "exitNote": "缺道路资料"]
            var times = station["timetables"] as! [[String: Any]]
            times[0]["validFrom"] = NSNull()
            times[0]["last"] = ["clock": "00:17", "dayOffset": 1]
            var short = times[0]
            short["id"] = "short"
            short["first"] = NSNull()
            short["last"] = ["clock": "23:32", "dayOffset": 0]
            short["lastDestination"] = "龙华"
            short["serviceLabel"] = "半程末班"
            short["verifiedAt"] = "2026-09-28"
            times.append(short)
            station["timetables"] = times
            var exits = station["exits"] as! [[String: Any]]
            exits[0]["description"] = NSNull()
            station["exits"] = exits
        }
        let repository = try decode(json)
        let station = try XCTUnwrap(repository.station("baoti"))
        XCTAssertNil(station.timetables[0].validFrom)
        XCTAssertEqual(station.timetables[0].last?.display, "次日 00:17")
        XCTAssertEqual(station.timetables[1].serviceLabel, "半程末班")
        XCTAssertEqual(station.timetables[1].lastDestination, "龙华")
        XCTAssertNil(station.timetables[1].first)
        XCTAssertNil(station.exits[0].description)
        XCTAssertNil(station.exits[0].coordinate)
        XCTAssertEqual(station.serviceReview?.timetableStatus, .reviewed)
        XCTAssertEqual(station.serviceReview?.exitStatus, .partial)
        var route = RouteSelection()
        route.origin = .station("baoanzhongxin")
        route.destination = .exit(stationID: "baoti", exitID: "exit-d")
        XCTAssertThrowsError(try repository.navigationRequest(route: route, location: nil))
    }

    func testV2RejectsEmptyTimesInvalidDatesAndWrongSourcesOrLines() throws {
        let changes: [[String: Any]] = [
            ["first": NSNull(), "last": NSNull()],
            ["validFrom": "2026-02-30"], ["validFrom": "2026-9-01"],
            ["validFrom": "2026-09-02", "validThrough": "2026-09-01"],
            ["validThrough": "not-a-date"], ["verifiedAt": "2026-09-31"], ["updatedAt": ""],
            ["sourceIDs": ["missing"]], ["sourceIDs": []], ["lineID": "l5"],
            ["first": ["clock": "06:20", "dayOffset": 0], "last": ["clock": "00:17", "dayOffset": 0]],
            ["first": ["clock": "--", "dayOffset": 0]], ["serviceLabel": " "]
        ]
        for change in changes {
            var json = try fixture()
            try setServices(&json, version: 2)
            try mutateStation(&json) { station in
                var records = station["timetables"] as! [[String: Any]]
                records[0].merge(change) { _, new in new }
                station["timetables"] = records
            }
            XCTAssertThrowsError(try decode(json), "\(change)")
        }
    }

    func testV2RejectsInvalidExitAndReviewMetadata() throws {
        let changes: [[String: Any]] = [["verifiedAt": "2026-02-29"], ["updatedAt": "today"],
                                        ["sourceIDs": ["missing"]], ["name": " "], ["description": ""]]
        for change in changes {
            var json = try fixture()
            try setServices(&json, version: 2)
            try mutateStation(&json) { station in
                var exits = station["exits"] as! [[String: Any]]
                exits[0].merge(change) { _, new in new }
                station["exits"] = exits
            }
            XCTAssertThrowsError(try decode(json), "\(change)")
        }
        for review in [["timetableStatus": "complete", "exitStatus": "partial"],
                       ["timetableStatus": "reviewed", "exitStatus": "partial", "verifiedAt": "2026-04-31"]] {
            var json = try fixture()
            json["schemaVersion"] = 2
            try mutateStation(&json) { $0["serviceReview"] = review }
            XCTAssertThrowsError(try decode(json))
        }
    }

    func testSourcePublicationAndAccessDatesAreStrict() throws {
        for key in ["sourcePublishedAt", "accessedAt"] {
            var json = try fixture()
            var sources = json["sources"] as! [[String: Any]]
            sources[0][key] = "2026-02-30"
            json["sources"] = sources
            XCTAssertThrowsError(try decode(json), key)
        }
    }

    func testCompletePackageAcceptsV1V2AndRejectsCorruptionAndVersionMismatch() throws {
        let svg = Data("<svg/>".utf8)
        for version in [1, 2] {
            var json = try fixture()
            try setServices(&json, version: version)
            let city = try JSONSerialization.data(withJSONObject: json)
            var manifest: [String: Any] = ["schemaVersion": version, "cityID": json["cityID"]!,
                                         "version": json["version"]!,
                                         "files": ["city.json": hash(city), "map.svg": hash(svg)]]
            func load(cityData: Data = city, svgData: Data = svg) throws -> CityRepository {
                try CityRepository(manifestData: JSONSerialization.data(withJSONObject: manifest), cityData: cityData, svgData: svgData)
            }
            XCTAssertEqual(try load().pack.schemaVersion, version)
            XCTAssertThrowsError(try load(cityData: city + Data(" ".utf8)))
            XCTAssertThrowsError(try load(svgData: Data("<svg>changed</svg>".utf8)))
            manifest["schemaVersion"] = version == 1 ? 2 : 1
            XCTAssertThrowsError(try load())
            manifest["schemaVersion"] = 99
            XCTAssertThrowsError(try load())
            manifest["schemaVersion"] = version
            manifest["version"] = "wrong-version"
            XCTAssertThrowsError(try load())
        }
    }

    func testDatedNarrativeNoticesRemainSeparateFromExactTimetables() throws {
        var json = try fixture()
        json["schemaVersion"] = 2
        try mutateStation(&json) { $0["serviceNotices"] = [noticeFixture()] }
        let station = try XCTUnwrap(decode(json).station("baoti"))
        let notice = try XCTUnwrap(station.serviceNotices?.first)
        XCTAssertEqual(notice.text, "指定日期延时，末班不早于次日01:00，以运营方安排为准。")
        XCTAssertEqual(notice.serviceDates, ["2026-09-30", "2026-10-01"])
        XCTAssertNil(notice.validFrom)
        XCTAssertTrue(station.timetables.isEmpty)
        var ranged = noticeFixture()
        ranged["serviceDates"] = [] as [String]
        ranged["validFrom"] = "2026-09-30"
        ranged["validThrough"] = "2026-10-07"
        try mutateStation(&json) { $0["serviceNotices"] = [ranged] }
        XCTAssertEqual(try decode(json).station("baoti")?.serviceNotices?.first?.validThrough, "2026-10-07")
    }

    func testNoticesRejectMissingDatesBadRangesDuplicateIDsAndInvalidSources() throws {
        let changes: [[String: Any]] = [
            ["id": " "], ["text": ""], ["serviceDates": []],
            ["serviceDates": ["2026-10-01", "2026-10-01"]],
            ["serviceDates": ["2026-10-01", "2026-09-30"]],
            ["serviceDates": ["2026-09-31"]], ["verifiedAt": "2026-02-30"],
            ["validFrom": "2026-10-07", "validThrough": "2026-10-01"],
            ["validFrom": "2026-9-30"], ["validThrough": "unknown"],
            ["sourceIDs": []], ["sourceIDs": ["missing"]]
        ]
        for change in changes {
            var json = try fixture()
            json["schemaVersion"] = 2
            var notice = noticeFixture()
            notice.merge(change) { _, new in new }
            try mutateStation(&json) { $0["serviceNotices"] = [notice] }
            XCTAssertThrowsError(try decode(json), "\(change)")
        }
        var json = try fixture()
        json["schemaVersion"] = 2
        try mutateStation(&json) { $0["serviceNotices"] = [noticeFixture(), noticeFixture()] }
        XCTAssertThrowsError(try decode(json))
    }

    private func noticeFixture() -> [String: Any] {
        ["id": "dated-reference", "text": "指定日期延时，末班不早于次日01:00，以运营方安排为准。",
         "serviceDates": ["2026-09-30", "2026-10-01"], "sourceIDs": ["sample"], "verifiedAt": "2026-09-28"]
    }

    private func fixture() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("tools/tests/fixtures/sample-city.json")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func setServices(_ json: inout [String: Any], version: Int) throws {
        json["schemaVersion"] = version
        try mutateStation(&json) { station in
            station["timetables"] = [["id": "regular", "lineID": "l1", "direction": "机场东", "serviceDays": "工作日",
                                      "validFrom": "2026-09-01", "first": ["clock": "06:20", "dayOffset": 0],
                                      "last": ["clock": "23:00", "dayOffset": 0], "sourceIDs": ["sample"], "updatedAt": "2026-09-28"]]
            station["exits"] = [["id": "exit-d", "name": "D出入口", "description": "道路资料", "coordinate": NSNull(),
                                 "sourceIDs": ["sample"], "updatedAt": "2026-09-28"]]
        }
    }

    private func mutateStation(_ json: inout [String: Any], _ change: (inout [String: Any]) -> Void) throws {
        var stations = try XCTUnwrap(json["stations"] as? [[String: Any]])
        change(&stations[0])
        json["stations"] = stations
    }

    private func decode(_ json: [String: Any]) throws -> CityRepository {
        try CityRepository(data: JSONSerialization.data(withJSONObject: json))
    }
    private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
