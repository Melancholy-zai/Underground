import XCTest

final class UndergroundUITests: XCTestCase {
    func testCompactTimetableKeepsExitsAndRemovesMetadataSection() {
        let app = XCUIApplication()
        app.launch()
        openServiceStation("lisonglang", in: app)
        let table = app.otherElements["stationTimetables"]
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        scrollServiceDetail(until: app.staticTexts["日期"].firstMatch, in: app)
        XCTAssertTrue(app.staticTexts["适用日未注明"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["timetableReviewStatus"].exists)
        XCTAssertFalse(app.staticTexts["资料说明"].exists)
        XCTAssertEqual(table.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "本地整理：")).count, 0)
        XCTAssertEqual(table.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "核验日期：")).count, 0)
        XCTAssertEqual(table.links.count, 0)
        XCTAssertTrue(app.staticTexts["exitReviewStatus"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "compact-timetable-new-station"; shot.lifetime = .keepAlways; add(shot)
    }

    func testServiceShortTurnKeepsRegularAndHalfRouteLastTrains() {
        let app = XCUIApplication()
        app.launch()
        openServiceStation("guanlanhu", in: app)
        scrollServiceDetail(until: app.staticTexts["23:32"].firstMatch, in: app)
        scrollServiceDetail(until: app.staticTexts["至龙华"].firstMatch, in: app)
        XCTAssertTrue(app.staticTexts["23:02"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "半程")).firstMatch.exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "station-services-short-turn"; shot.lifetime = .keepAlways; add(shot)
    }

    func testServiceUnknownEffectiveDateAndNextDayRemainExplicit() {
        let app = XCUIApplication()
        app.launch()
        openServiceStation("qianhaiwan", in: app)
        scrollServiceDetail(until: app.staticTexts["次日 00:17"].firstMatch, in: app)
        XCTAssertTrue(app.staticTexts["工作日"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["休息日"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["节假日"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["生效日期未注明"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "深圳地铁：")).count, 0)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "station-services-next-day"; shot.lifetime = .keepAlways; add(shot)
    }

    func testServiceExitWithoutDescriptionDoesNotOfferExactNavigation() {
        let app = XCUIApplication()
        app.launch()
        openServiceStation("luohu", in: app)
        let missingDescription = app.staticTexts["道路／地标暂无资料"].firstMatch
        scrollServiceDetail(until: missingDescription, in: app)
        XCTAssertTrue(app.staticTexts["D出口"].firstMatch.exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "navigate-exit-")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["暂无已核实出口坐标，暂不提供精确出口导航。"].firstMatch.exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "station-services-exit-unknown"; shot.lifetime = .keepAlways; add(shot)
    }

    private func openServiceStation(_ query: String, in app: XCUIApplication) {
        let search = app.textFields["mapSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.tap(); search.typeText(query)
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "search-")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.buttons["closeDetail"].waitForExistence(timeout: 5))
    }

    private func scrollServiceDetail(until element: XCUIElement, in app: XCUIApplication,
                                     file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<45 {
            if element.exists && element.isHittable { return }
            app.scrollViews["stationDetailScroll"].swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "未找到站点资料项", file: file, line: line)
    }

    func testLegendSelectionToggleSwitchAndViewport() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["mapLegend"].waitForExistence(timeout: 15))
        app.buttons["mapLegend"].tap()
        app.buttons["focus-legend-lines"].tap()
        let legend = app.webViews.switches["2号线图例"]
        XCTAssertTrue(legend.waitForExistence(timeout: 10))
        let before = legend.frame
        legend.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["赤湾 ↔ 莲塘"].waitForExistence(timeout: 5))
        XCTAssertEqual(legend.value as? String, "1")
        XCTAssertEqual(app.webViews.switches["8号线图例"].value as? String, "0")
        XCTAssertEqual(legend.frame.minX, before.minX, accuracy: 1)
        XCTAssertEqual(legend.frame.minY, before.minY, accuracy: 1)
        XCTAssertEqual(legend.frame.width, before.width, accuracy: 1)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "legend-2-selected"; shot.lifetime = .keepAlways; add(shot)
        legend.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertFalse(app.staticTexts["赤湾 ↔ 莲塘"].exists)
        app.webViews.switches["1号线图例"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["罗湖 ↔ 机场东"].waitForExistence(timeout: 5))
        legend.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["赤湾 ↔ 莲塘"].waitForExistence(timeout: 5))
        app.buttons["lineList"].tap()
        app.buttons["line-l2"].tap()
        XCTAssertFalse(app.staticTexts["赤湾 ↔ 莲塘"].exists)
        legend.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["赤湾 ↔ 莲塘"].waitForExistence(timeout: 5))
        app.webViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.95)).tap()
        XCTAssertFalse(app.staticTexts["赤湾 ↔ 莲塘"].exists)
    }

    func testSurroundingsLegendsResetAndSearch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["showSurroundings"].waitForExistence(timeout: 15))
        let station = app.webViews.buttons["前海湾站"]
        XCTAssertTrue(station.waitForExistence(timeout: 10))
        let overviewFrame = station.frame
        app.buttons["showSurroundings"].tap()
        let moved = NSPredicate { _, _ in station.frame != overviewFrame }
        expectation(for: moved, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        let surroundings = XCTAttachment(screenshot: app.screenshot())
        surroundings.name = "surroundings-focus"; surroundings.lifetime = .keepAlways; add(surroundings)

        for id in ["legend-lines", "legend-symbols"] {
            app.buttons["mapLegend"].tap()
            let item = app.buttons["focus-" + id]
            XCTAssertTrue(item.waitForExistence(timeout: 5))
            item.tap()
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = id; shot.lifetime = .keepAlways; add(shot)
        }
        app.buttons["恢复全图"].tap()
        let restored = NSPredicate { _, _ in
            abs(station.frame.midX - overviewFrame.midX) < 1 && abs(station.frame.midY - overviewFrame.midY) < 1
        }
        expectation(for: restored, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        app.textFields["mapSearch"].tap()
        app.textFields["mapSearch"].typeText("qianhaiwan")
        XCTAssertTrue(app.buttons["search-qianhaiwan"].waitForExistence(timeout: 5))
        app.buttons["search-qianhaiwan"].tap()
        XCTAssertTrue(app.buttons["setOrigin"].waitForExistence(timeout: 5))
        app.buttons["closeDetail"].tap()
        app.buttons["showSurroundings"].tap()
        XCTAssertTrue(app.buttons["mapLegend"].exists)
    }

    func testCleanMapKeepsUncertaintyInDetailsAndDatesInAbout() {
        let app = XCUIApplication()
        app.launch()
        let search = app.textFields["mapSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "线网截止：")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "区界为示意 · 部分区属")).firstMatch.exists)
        search.tap(); search.typeText("hanling")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "search-")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.staticTexts["行政区待核实"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "冲突")).firstMatch.exists)
        let detail = XCTAttachment(screenshot: app.screenshot())
        detail.name = "uncertainty-detail"; detail.lifetime = .keepAlways; add(detail)
        app.buttons["closeDetail"].tap()
        let map = XCTAttachment(screenshot: app.screenshot())
        map.name = "clean-boundary-station"; map.lifetime = .keepAlways; add(map)
        app.buttons["资料"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "资料版本")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "2026-06-28")).firstMatch.exists)
    }

    func testDistrictOverviewAndStationDistrict() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.textFields["mapSearch"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["深圳，分区看地铁"].exists)
        XCTAssertTrue(app.webViews.buttons["前海湾站"].waitForExistence(timeout: 10))
        let overview = XCTAttachment(screenshot: app.screenshot())
        overview.name = "district-overview"; overview.lifetime = .keepAlways; add(overview)
        app.textFields["mapSearch"].tap()
        app.textFields["mapSearch"].typeText("wutongshannan")
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "search-")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.staticTexts["罗湖区"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["closeDetail"].tap()
        let boundary = XCTAttachment(screenshot: app.screenshot())
        boundary.name = "district-luohu-yantian"; boundary.lifetime = .keepAlways; add(boundary)
    }

    func testOfflineSearchDetailAndManualRoute() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.textFields["mapSearch"].waitForExistence(timeout: 15))
        app.textFields["mapSearch"].tap()
        app.textFields["mapSearch"].typeText("qianhaiwan")
        XCTAssertTrue(app.buttons["search-qianhaiwan"].waitForExistence(timeout: 5))
        app.buttons["search-qianhaiwan"].tap()
        XCTAssertTrue(app.buttons["setDestination"].waitForExistence(timeout: 5))
        app.buttons["setDestination"].tap()
        XCTAssertTrue(app.buttons["chooseOrigin"].waitForExistence(timeout: 5))
        app.buttons["chooseOrigin"].tap()
        let row = app.buttons["pick-taoyuan"]
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("taoyuan")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["chooseOrigin"].label.contains("桃园"))
        XCTAssertTrue(app.buttons["chooseDestination"].label.contains("前海湾"))
        XCTAssertTrue(app.buttons["swapRoute"].isEnabled)
        app.buttons["swapRoute"].tap()
        XCTAssertTrue(app.buttons["chooseOrigin"].label.contains("前海湾"))
        XCTAssertTrue(app.buttons["chooseDestination"].label.contains("桃园"))
        app.buttons["open-amap"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.firstMatch.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "高德地图")).firstMatch.exists)
        app.alerts.buttons["知道了"].tap()
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "manual-route"; shot.lifetime = .keepAlways; add(shot)
    }

    func testLineSelectionAndFocusedStationTap() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["lineList"].waitForExistence(timeout: 15))
        app.buttons["lineList"].tap()
        app.buttons["line-l1"].tap()
        XCTAssertTrue(app.staticTexts["罗湖 ↔ 机场东"].waitForExistence(timeout: 5))
        app.buttons["恢复全图"].tap()
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "offline-map"; shot.lifetime = .keepAlways; add(shot)
        // Focus first: a station on the entire landscape atlas is too small to tap reliably.
        app.textFields["mapSearch"].tap()
        app.textFields["mapSearch"].typeText("qianhaiwan")
        XCTAssertTrue(app.buttons["search-qianhaiwan"].waitForExistence(timeout: 5))
        app.buttons["search-qianhaiwan"].tap()
        XCTAssertTrue(app.buttons["closeDetail"].waitForExistence(timeout: 5))
        app.buttons["closeDetail"].tap()
        // Exercise the actual SVG station hit after dismissing the search result's detail.
        let station = app.webViews.buttons["前海湾站"]
        XCTAssertTrue(station.waitForExistence(timeout: 10))
        let map = app.webViews.firstMatch
        // Search centers the station marker. The SVG group's AX frame also contains
        // its label and the whitespace between them; its midpoint is not the marker.
        XCTAssertTrue(station.frame.contains(CGPoint(x: map.frame.midX, y: map.frame.midY)))
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["setOrigin"].waitForExistence(timeout: 5))
    }
    func testFullNetworkExtensionAndPolyphonicHubSearch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.textFields["mapSearch"].waitForExistence(timeout: 15))
        for (query, identifier, expectedLine) in [
            ("gangxiabei", "search-s_56f42681a960", "14号线"),
            ("lisonglang", "search-s_af414751b3c8", "13号线")
        ] {
            app.textFields["mapSearch"].tap()
            app.textFields["mapSearch"].typeText(query)
            XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 5))
            app.buttons[identifier].tap()
            XCTAssertTrue(app.staticTexts[expectedLine].firstMatch.waitForExistence(timeout: 5))
            app.buttons["closeDetail"].tap()
            XCTAssertTrue(app.textFields["mapSearch"].waitForExistence(timeout: 5))
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "network-" + query; shot.lifetime = .keepAlways; add(shot)
        }
    }

}
