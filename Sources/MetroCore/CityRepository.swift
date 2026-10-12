import Foundation
import CryptoKit

public final class CityRepository {
    public let pack: CityPack
    private let stationsByID: [String: Station]
    private let linesByID: [String: MetroLine]
    private let searchKeys: [String: [String]]

    public init(data: Data) throws {
        let pack = try JSONDecoder().decode(CityPack.self, from: data)
        try Self.validate(pack)
        self.pack = pack
        stationsByID = Dictionary(uniqueKeysWithValues: pack.stations.map { ($0.id, $0) })
        linesByID = Dictionary(uniqueKeysWithValues: pack.lines.map { ($0.id, $0) })
        searchKeys = Dictionary(uniqueKeysWithValues: pack.stations.map { station in
            let pinyin = station.name.applyingTransform(.toLatin, reverse: false)?
                .folding(options: .diacriticInsensitive, locale: .current) ?? ""
            let initials = pinyin.split(separator: " ").compactMap(\.first).map(String.init).joined()
            return (station.id, ([station.name, pinyin, initials] + station.aliases).map(Self.normalize))
        })
    }

    /// Verify both payload hashes and their identity before accepting a complete package.
    /// The app and tests share this path so corrupt or mixed-version files cannot bypass validation.
    public convenience init(manifestData: Data, cityData: Data, svgData: Data) throws {
        struct Manifest: Decodable {
            let schemaVersion: Int
            let cityID: String
            let version: String
            let files: [String: String]
        }
        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        guard [1, 2].contains(manifest.schemaVersion), Set(manifest.files.keys) == ["city.json", "map.svg"] else {
            throw MetroError.invalidData("资料包清单不受支持")
        }
        for (name, data) in [("city.json", cityData), ("map.svg", svgData)] {
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard hash == manifest.files[name] else {
                throw MetroError.invalidData("\(name) 与资料清单不一致，请完整替换资料包")
            }
        }
        try self.init(data: cityData)
        guard pack.schemaVersion == manifest.schemaVersion, pack.cityID == manifest.cityID,
              pack.version == manifest.version else {
            throw MetroError.invalidData("清单、地图与城市资料版本不匹配")
        }
    }

    public func station(_ id: String) -> Station? { stationsByID[id] }
    public func line(_ id: String) -> MetroLine? { linesByID[id] }
    public func lines(at stationID: String) -> [MetroLine] { station(stationID)?.lineIDs.compactMap(line) ?? [] }
    public func districtName(for station: Station) -> String {
        let names = station.districtIDs.compactMap { id in pack.districts.first { $0.id == id }?.name }
        return names.isEmpty ? "行政区待核实" : names.joined(separator: " / ")
    }
    public func sources(_ ids: [String]) -> [DataSource] { ids.compactMap { id in pack.sources.first { $0.id == id } } }
    public func search(_ query: String) -> [Station] {
        let key = Self.normalize(query)
        guard !key.isEmpty else { return pack.stations }
        return pack.stations.filter { searchKeys[$0.id]?.contains(where: { $0.contains(key) }) == true }
            .sorted { a, b in
                let aExact = Self.normalize(a.name) == key
                let bExact = Self.normalize(b.name) == key
                if aExact != bExact { return aExact }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
    }

    public func navigationRequest(route: RouteSelection, location: GeoCoordinate?) throws -> NavigationRequest {
        try route.validate()
        let origin: NavigationEndpoint
        switch route.origin {
        case .currentLocation:
            guard let location, location.isValid else { throw MetroError.invalidRoute("尚未取得当前位置，可重试或手动选择起点") }
            origin = NavigationEndpoint(name: "当前位置", coordinate: location)
        case .station(let id): origin = try stationEndpoint(id)
        }
        let destination: NavigationEndpoint
        switch route.destination {
        case .station(let id): destination = try stationEndpoint(id)
        case .exit(let stationID, let exitID):
            guard let station = station(stationID), let exit = station.exits.first(where: { $0.id == exitID }),
                  let coordinate = exit.coordinate, !exit.sourceIDs.isEmpty else {
                throw MetroError.invalidRoute("该出口暂无已核实坐标，请选择车站")
            }
            destination = NavigationEndpoint(name: pack.cityName + station.name + "站" + exit.name, coordinate: coordinate)
        case nil: throw MetroError.invalidRoute("请先选择终点站")
        }
        return NavigationRequest(origin: origin, destination: destination, mode: route.mode, city: pack.cityName)
    }

    private func stationEndpoint(_ id: String) throws -> NavigationEndpoint {
        guard let station = station(id) else { throw MetroError.invalidRoute("站点不在当前资料包中") }
        return NavigationEndpoint(name: pack.cityName + station.name + "地铁站", coordinate: station.coordinate,
                                  amapLocation: station.amapLocation)
    }
    private static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "zh_CN"))
            .components(separatedBy: .whitespacesAndNewlines).joined()
    }

    private static func validate(_ pack: CityPack) throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw MetroError.invalidData(message) }
        }
        func unique(_ ids: [String]) -> Bool { Set(ids).count == ids.count && ids.allSatisfy { !$0.isEmpty } }
        func nonempty(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.isLenient = false
        func validDate(_ value: String) -> Bool {
            guard value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
                  let date = dateFormatter.date(from: value) else { return false }
            return dateFormatter.string(from: date) == value
        }
        func optionalDate(_ value: String?) -> Bool { value.map(validDate) ?? true }
        try require([1, 2].contains(pack.schemaVersion), "不支持此资料包版本")
        try require(!pack.stations.isEmpty && !pack.lines.isEmpty, "城市资料包为空")
        try require(pack.map.width > 0 && pack.map.height > 0, "地图尺寸无效")
        try require(unique(pack.stations.map(\.id)) && unique(pack.lines.map(\.id)) &&
                    unique(pack.districts.map(\.id)) && unique(pack.sources.map(\.id)), "资料中存在重复或空编号")
        let stationIDs = Set(pack.stations.map(\.id)), lineIDs = Set(pack.lines.map(\.id))
        let districtIDs = Set(pack.districts.map(\.id)), sourceIDs = Set(pack.sources.map(\.id))
        for source in pack.sources {
            try require(validDate(source.accessedAt) && optionalDate(source.sourcePublishedAt), "来源访问或发布日期无效")
        }
        try pack.mapContext?.validate(map: pack.map, sourceIDs: sourceIDs, stationIDs: stationIDs)
        if let review = pack.networkReview {
            try require(pack.dataAsOf != nil && !review.reviewedAt.isEmpty &&
                        review.lineCount == pack.lines.count && review.stationCount == pack.stations.count &&
                        review.membershipCount == pack.lines.reduce(0, { $0 + $1.stationIDs.count }) &&
                        !review.sourceIDs.isEmpty && Set(review.sourceIDs).isSubset(of: sourceIDs), "线网核验记录与资料不一致")
        }
        if !pack.isSample && (pack.networkReview == nil || pack.coverageReview != nil) {
            guard let review = pack.coverageReview, let cutoff = pack.dataAsOf else {
                throw MetroError.invalidData("正式资料缺少截止日或人工核验记录")
            }
            try require(!cutoff.isEmpty && !review.reviewer.isEmpty && !review.reviewedAt.isEmpty &&
                        review.completeNetwork && review.usageRightsConfirmed && review.districtsReviewed &&
                        !review.sourceIDs.isEmpty && Set(review.sourceIDs).isSubset(of: sourceIDs), "正式资料核验不完整")
            try require(pack.stations.allSatisfy { $0.coordinate != nil }, "正式资料缺少站点真实坐标")
        }
        for service in pack.throughServices ?? [] {
            try require(service.fromStationID != service.toStationID && service.lineIDs.count == 2 &&
                        Set(service.lineIDs).count == 2 && !service.note.isEmpty, "贯通连接无效")
            let endpoints = [service.fromStationID, service.toStationID]
            for (index, lineID) in service.lineIDs.enumerated() {
                let line = pack.lines.first { $0.id == lineID }
                try require(line?.stationIDs.first == endpoints[index] || line?.stationIDs.last == endpoints[index], "贯通连接必须连接对应线路端点")
            }
        }
        for line in pack.lines {
            try require(line.stationIDs.count >= 2 && unique(line.stationIDs) && Set(line.stationIDs).isSubset(of: stationIDs), "线路站点关联错误：\(line.name)")
            try require(Set(line.sourceIDs).isSubset(of: sourceIDs), "线路来源缺失")
        }
        for station in pack.stations {
            try require(!station.name.isEmpty && !station.lineIDs.isEmpty && unique(station.lineIDs) &&
                        Set(station.lineIDs).isSubset(of: lineIDs), "站点线路关联错误：\(station.name)")
            let memberships = Set(pack.lines.filter { $0.stationIDs.contains(station.id) }.map(\.id))
            try require(memberships == Set(station.lineIDs), "换乘关系不一致：\(station.name)")
            try require(Set(station.districtIDs).isSubset(of: districtIDs), "站点行政区缺失")
            try require(Set(station.sourceIDs + station.coordinateSourceIDs).isSubset(of: sourceIDs), "站点来源缺失")
            try require(station.diagram.x >= 0 && station.diagram.x <= pack.map.width &&
                        station.diagram.y >= 0 && station.diagram.y <= pack.map.height, "站点示意坐标越界")
            if let coordinate = station.coordinate {
                try require(coordinate.isValid && !station.coordinateSourceIDs.isEmpty, "真实坐标无效或未经核实")
            }
            if let location = station.amapLocation {
                try require(location.isValid && !location.sourceIDs.isEmpty &&
                            Set(location.sourceIDs).isSubset(of: sourceIDs) && !location.updatedAt.isEmpty,
                            "高德站点位置无效或未经核实")
            }
            try require(unique(station.exits.map(\.id)) && unique(station.timetables.map(\.id)), "站内资料编号重复")
            if let review = station.serviceReview {
                try require(optionalDate(review.verifiedAt), "服务资料核验日期无效")
            }
            let notices = station.serviceNotices ?? []
            try require(unique(notices.map(\.id)) && notices.allSatisfy { nonempty($0.id) }, "日期调整说明编号重复或为空")
            for notice in notices {
                try require(nonempty(notice.text), "日期调整说明为空")
                try require(!notice.sourceIDs.isEmpty && Set(notice.sourceIDs).isSubset(of: sourceIDs), "日期调整说明缺少来源")
                try require(validDate(notice.verifiedAt) && optionalDate(notice.validFrom) && optionalDate(notice.validThrough) &&
                            notice.serviceDates.allSatisfy(validDate), "日期调整说明日期无效")
                try require(unique(notice.serviceDates) && notice.serviceDates == notice.serviceDates.sorted(), "日期调整说明适用日期重复或未排序")
                try require(!notice.serviceDates.isEmpty || notice.validFrom != nil, "日期调整说明缺少明确适用日期")
                if let start = notice.validFrom, let end = notice.validThrough {
                    try require(start <= end, "日期调整说明截止日期早于生效日期")
                }
            }
            for exit in station.exits {
                try require(nonempty(exit.name), "出口名称为空")
                try require(exit.description.map(nonempty) ?? (pack.schemaVersion == 2), "出口描述无效")
                try require(validDate(exit.updatedAt) && optionalDate(exit.verifiedAt), "出口整理或核验日期无效")
                try require(!exit.sourceIDs.isEmpty && Set(exit.sourceIDs).isSubset(of: sourceIDs), "出口缺少来源")
                try require(exit.coordinate?.isValid != false, "出口坐标无效")
            }
            for time in station.timetables {
                try require(time.validFrom.map(validDate) ?? (pack.schemaVersion == 2), "时刻生效日期无效")
                try require(optionalDate(time.validThrough) && validDate(time.updatedAt) && optionalDate(time.verifiedAt), "时刻截止、整理或核验日期无效")
                if let start = time.validFrom, let end = time.validThrough {
                    try require(start <= end, "时刻截止日期早于生效日期")
                }
                if pack.schemaVersion == 2 {
                    try require(time.first != nil || time.last != nil, "时刻首末班不能同时缺失")
                    try require(time.serviceLabel.map(nonempty) ?? true, "特殊服务标签为空")
                }
                try require(station.lineIDs.contains(time.lineID) && nonempty(time.direction) && nonempty(time.serviceDays),
                            "时刻缺少本站线路、方向或适用条件")
                try require(!time.sourceIDs.isEmpty && Set(time.sourceIDs).isSubset(of: sourceIDs), "时刻缺少来源")
                if let first = time.first, let last = time.last {
                    try require(first.minutes <= last.minutes, "末班早于首班，请检查次日标记")
                }
            }
        }
    }
}
