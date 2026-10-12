import XCTest
@testable import MetroCore

final class CoreTests: XCTestCase {
    func testServiceTimeDistinguishesNextDay() throws {
        XCTAssertEqual(try ServiceTime(clock: "00:12", dayOffset: 1).display, "次日 00:12")
        XCTAssertEqual(try ServiceTime(clock: "23:52", dayOffset: 0).minutes, 1432)
        XCTAssertThrowsError(try ServiceTime(clock: "24:12", dayOffset: 0))
        XCTAssertThrowsError(try ServiceTime(clock: "9:12", dayOffset: 0))
        XCTAssertThrowsError(try ServiceTime(clock: "00:00", dayOffset: -1))
    }

    func testSwapRequiresTwoStationsAndRejectsSameStation() throws {
        var route = RouteSelection()
        route.destination = .station("b")
        XCTAssertFalse(route.canSwap)
        route.swap()
        XCTAssertEqual(route.origin, .currentLocation)
        route.origin = .station("a")
        route.swap()
        XCTAssertEqual(route.origin, .station("b"))
        XCTAssertEqual(route.destination, .station("a"))
        route.destination = .station("b")
        XCTAssertThrowsError(try route.validate())
    }

    func testManualOriginSurvivesLocationResults() {
        /Users/phy/Documents/Underground/Tests/MetroCoreTests/TimetablePresentationTests.swift  var route = RouteSelection()
        route.origin = .station("a")
        let snapshot = route
        route.destination = .station("b")
        XCTAssertNotEqual(route, snapshot)
        // Location is an input to request construction, never a mutating origin setter.
        XCTAssertEqual(route.origin, .station("a"))
    }

    func testDelayedCancellationCannotFinishNewRequest() {
        var gate = RequestGate()
        let previous = gate.begin()
        let current = gate.begin()
        XCTAssertFalse(gate.finish(previous))
        XCTAssertTrue(gate.accepts(current))
        XCTAssertTrue(gate.finish(current))
        XCTAssertFalse(gate.finish(current))
    }

    func testAmapPreservesPositionAndEscapesNames() throws {
        let request = NavigationRequest(origin: .init(name: "深圳 A&B 站", coordinate: .init(latitude: 22.5, longitude: 114, system: .wgs84)),
                                        destination: .init(name: "深圳 前海湾站", coordinate: nil), mode: .transit)
        let url = try NavigationURLBuilder.url(for: .amap, request: request)
        let query = items(url)
        XCTAssertEqual(url.scheme, "iosamap")
        XCTAssertEqual(query["sname"], "深圳 A&B 站")
        XCTAssertEqual(query["dname"], "深圳 前海湾站")
        XCTAssertEqual(query["t"], "1")
        XCTAssertEqual(query["slat"], "22.500000")
        XCTAssertFalse(url.absoluteString.contains("A&B"))
    }

    func testAmapRejectsNameOnlyOriginInsteadOfAllowingCurrentLocationFallback() {
        let request = NavigationRequest(origin: .init(name: "深圳桃园地铁站", coordinate: nil),
                                        destination: .init(name: "深圳前海湾地铁站", coordinate: nil), mode: .transit)
        XCTAssertThrowsError(try NavigationURLBuilder.url(for: .amap, request: request))
        XCTAssertNoThrow(try NavigationURLBuilder.url(for: .baidu, request: request))
    }

    func testCoordinatesHaveExplicitDatumAndLatitudeOrder() throws {
        let start = GeoCoordinate(latitude: 22.5, longitude: 113.9, system: .wgs84)
        let end = GeoCoordinate(latitude: 22.6, longitude: 114.0, system: .wgs84)
        let request = NavigationRequest(origin: .init(name: "当前位置", coordinate: start),
                                        destination: .init(name: "终点", coordinate: end), mode: .walking)
        let amap = items(try NavigationURLBuilder.url(for: .amap, request: request))
        XCTAssertEqual(amap["dev"], "1")
        XCTAssertEqual(amap["slat"], "22.500000")
        XCTAssertEqual(amap["t"], "2")
        let baidu = items(try NavigationURLBuilder.url(for: .baidu, request: request))
        XCTAssertEqual(baidu["coord_type"], "wgs84")
        XCTAssertEqual(baidu["origin"], "name:当前位置|latlng:22.500000,113.900000")
        XCTAssertEqual(baidu["mode"], "walking")
    }

    func testBaiduNameOnlyDoesNotUseNamePrefix() throws {
        let request = NavigationRequest(origin: .init(name: "深圳桃园地铁站", coordinate: nil),
                                        destination: .init(name: "深圳前海湾地铁站", coordinate: nil), mode: .transit)
        let query = items(try NavigationURLBuilder.url(for: .baidu, request: request))
        XCTAssertEqual(query["origin"], "深圳桃园地铁站")
        XCTAssertEqual(query["region"], "深圳")
    }

    func testInvalidCoordinatesAreRejected() {
        let request = NavigationRequest(origin: .init(name: "", coordinate: .init(latitude: 200, longitude: 20, system: .wgs84)),
                                        destination: .init(name: "终点", coordinate: nil), mode: .transit)
        XCTAssertThrowsError(try NavigationURLBuilder.url(for: .amap, request: request))
    }

    func testBundledPackSearchAndIntegrity() throws {
        let repo = try repository()
        XCTAssertFalse(repo.pack.isSample)
        XCTAssertEqual(repo.pack.lines.count, 17)
        XCTAssertEqual(repo.pack.stations.count, 351)
        XCTAssertTrue(repo.pack.needsMetadata)
        XCTAssertEqual(repo.pack.throughServices?.count, 1)
        XCTAssertEqual(repo.search(" 前海湾 ").first?.id, "qianhaiwan")
        XCTAssertEqual(repo.search("QHW").first?.id, "qianhaiwan")
        XCTAssertEqual(repo.search("qianhaiwan").first?.id, "qianhaiwan")
        XCTAssertTrue(repo.search("不存在的医院").isEmpty)
        XCTAssertEqual(repo.search("gangxiabei").first?.name, "岗厦北")
        XCTAssertEqual(repo.search("shixia").first?.name, "石厦")
        XCTAssertEqual(repo.search("songyuanxia").first?.name, "松元厦")
        XCTAssertEqual(repo.search("maling").first?.name, "孖岭")
        XCTAssertEqual(repo.lines(at: "qianhaiwan").count, 3)
        XCTAssertTrue(repo.station("qianhaiwan")?.timetables.allSatisfy {
            !$0.sourceIDs.isEmpty && $0.sourceIDs.allSatisfy { id in repo.pack.sources.contains { $0.id == id } }
        } == true)
    }

    func testManualRequestIgnoresSuppliedCurrentLocation() throws {
        let repo = try repository()
        var route = RouteSelection()
        route.origin = .station("taoyuan")
        route.destination = .station("qianhaiwan")
        let request = try repo.navigationRequest(route: route, location: .init(latitude: 22, longitude: 114, system: .wgs84))
        XCTAssertEqual(request.origin.name, "深圳桃园地铁站")
        XCTAssertNil(request.origin.coordinate)
        route.origin = .currentLocation
        XCTAssertThrowsError(try repo.navigationRequest(route: route, location: nil))
    }

    func testAmapManualOriginIncludesStationIdentityAndPosition() throws {
        let repo = try repository()
        var route = RouteSelection()
        route.origin = .station("taoyuan")
        route.destination = .station("qianhaiwan")
        let query = items(try NavigationURLBuilder.url(for: .amap,
            request: repo.navigationRequest(route: route, location: .init(latitude: 22, longitude: 114, system: .wgs84))))
        XCTAssertEqual(query["sid"], "BV10249851")
        XCTAssertEqual(query["did"], "BV10249931")
        XCTAssertEqual(query["slat"], "22.531506")
        XCTAssertEqual(query["slon"], "113.924781")
        XCTAssertEqual(query["dlat"], "22.537121")
        XCTAssertEqual(query["dlon"], "113.897932")
        XCTAssertEqual(query["dev"], "0")
        route.swap()
        let swapped = items(try NavigationURLBuilder.url(for: .amap,
            request: repo.navigationRequest(route: route, location: nil)))
        XCTAssertEqual(swapped["sid"], query["did"])
        XCTAssertEqual(swapped["slat"], query["dlat"])
        XCTAssertEqual(swapped["did"], query["sid"])
    }

    func testAmapCurrentLocationRetainsWGS84AndResolvesDestinationByPOI() throws {
        let repo = try repository()
        var route = RouteSelection()
        route.destination = .station("qianhaiwan")
        let query = items(try NavigationURLBuilder.url(for: .amap,
            request: repo.navigationRequest(route: route, location: .init(latitude: 22.5, longitude: 114, system: .wgs84))))
        XCTAssertEqual(query["sname"], "当前位置")
        XCTAssertEqual(query["slat"], "22.500000")
        XCTAssertEqual(query["slon"], "114.000000")
        XCTAssertEqual(query["dev"], "1")
        XCTAssertNil(query["sid"])
        XCTAssertEqual(query["did"], "BV10249931")
        // The single dev flag applies to both endpoints. Never mix GCJ02 with WGS84.
        XCTAssertNil(query["dlat"])
        XCTAssertNil(query["dlon"])
    }

    func testEveryBundledStationCanBeAnExplicitAmapOrigin() throws {
        let repo = try repository()
        for station in repo.pack.stations {
            var route = RouteSelection()
            route.origin = .station(station.id)
            route.destination = .station(station.id == "taoyuan" ? "qianhaiwan" : "taoyuan")
            let query = items(try NavigationURLBuilder.url(for: .amap,
                request: repo.navigationRequest(route: route, location: nil)))
            XCTAssertNotNil(query["sid"], station.name)
            XCTAssertNotNil(query["slat"], station.name)
            XCTAssertNotNil(query["slon"], station.name)
            XCTAssertEqual(query["dev"], "0", station.name)
        }
    }

    func testAmapPositionRequiresCorrectDatumAndProvenance() throws {
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: packURL)) as? [String: Any])
        for (key, value) in [("system", "wgs84" as Any), ("sourceIDs", [] as [String]),
                             ("poiID", ""), ("latitude", 200)] {
            var json = original
            var stations = try XCTUnwrap(json["stations"] as? [[String: Any]])
            var location = try XCTUnwrap(stations[0]["amapLocation"] as? [String: Any])
            location[key] = value; stations[0]["amapLocation"] = location; json["stations"] = stations
            XCTAssertThrowsError(try CityRepository(data: JSONSerialization.data(withJSONObject: json)), key)
        }
    }

    func testAmapDoesNotMislabelWGS84ExitAsGCJ02() throws {
        let repo = try repository()
        let request = NavigationRequest(
            origin: .init(name: "桃园", coordinate: nil, amapLocation: repo.station("taoyuan")?.amapLocation),
            destination: .init(name: "出口", coordinate: .init(latitude: 22.5, longitude: 114, system: .wgs84)), mode: .walking)
        XCTAssertThrowsError(try NavigationURLBuilder.url(for: .amap, request: request))
    }

    func testMalformedAndDuplicatePackRejected() throws {
        let data = try Data(contentsOf: packURL)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var stations = try XCTUnwrap(json["stations"] as? [[String: Any]])
        stations.append(stations[0])
        json["stations"] = stations
        XCTAssertThrowsError(try CityRepository(data: JSONSerialization.data(withJSONObject: json)))
        json["schemaVersion"] = 99
        XCTAssertThrowsError(try CityRepository(data: JSONSerialization.data(withJSONObject: json)))
    }

    func testDisablingSampleFlagRequiresProductionReview() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: packURL)) as? [String: Any])
        json["isSample"] = false
        json.removeValue(forKey: "networkReview")
        XCTAssertThrowsError(try CityRepository(data: JSONSerialization.data(withJSONObject: json)))
    }

    func testNetworkReviewCountsAndThroughEndpointsAreValidated() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: packURL)) as? [String: Any])
        var review = try XCTUnwrap(json["networkReview"] as? [String: Any])
        review["stationCount"] = 17
        json["networkReview"] = review
        XCTAssertThrowsError(try CityRepository(data: JSONSerialization.data(withJSONObject: json)))
        json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: packURL)) as? [String: Any])
        var services = try XCTUnwrap(json["throughServices"] as? [[String: Any]])
        services[0]["fromStationID"] = "qianhaiwan"
        json["throughServices"] = services
        XCTAssertThrowsError(try CityRepository(data: JSONSerialization.data(withJSONObject: json)))
    }

    func testUnknownStationAndUnverifiedExitCannotNavigate() throws {
        let repo = try repository()
        var route = RouteSelection()
        route.origin = .station("taoyuan")
        route.destination = .station("missing")
        XCTAssertThrowsError(try repo.navigationRequest(route: route, location: nil))
        route.destination = .exit(stationID: "taoyuan", exitID: "missing")
        XCTAssertThrowsError(try repo.navigationRequest(route: route, location: nil))
    }

    func testMapContextSourcesBoundariesAndFocusFrames() throws {
        let repo = try repository()
        let context = try XCTUnwrap(repo.pack.mapContext)
        XCTAssertEqual(context.reviewedAt, "2026-09-28")
        XCTAssertEqual(Set(context.boundaries.map(\.kind)), [.city, .region, .coast])
        XCTAssertEqual(context.stationNotes.count, 6)
        XCTAssertEqual(Set(context.focusAreas.map(\.id)), ["surroundings", "legend-lines", "legend-symbols"])
        XCTAssertTrue(context.focusAreas.allSatisfy { $0.frame.fits(width: repo.pack.map.width, height: repo.pack.map.height) })
    }

    func testInvalidMapContextSourceAndFrameAreRejected() throws {
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: packURL)) as? [String: Any])
        var json = original
        var context = try XCTUnwrap(json["mapContext"] as? [String: Any])
        context["sourceIDs"] = ["missing"]
        json["mapContext"] = context
        XCTAssertThrowsError(try CityRepository(data: JSONSerialization.data(withJSONObject: json)))
        context = try XCTUnwrap(original["mapContext"] as? [String: Any])
        var frames = try XCTUnwrap(context["focusAreas"] as? [[String: Any]])
        frames[0]["frame"] = ["x": 0, "y": 0, "width": 1_000_000, "height": 100]
        context["focusAreas"] = frames
        json["mapContext"] = context
        XCTAssertThrowsError(try CityRepository(data: JSONSerialization.data(withJSONObject: json)))
    }

    private var packURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("App/Resources/CityPack/city.json")
    }
    private func repository() throws -> CityRepository { try CityRepository(data: Data(contentsOf: packURL)) }
    private func items(_ url: URL) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .map { ($0.name, $0.value ?? "") })
    }
}
