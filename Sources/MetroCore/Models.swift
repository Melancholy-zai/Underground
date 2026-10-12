import Foundation

public enum MetroError: LocalizedError, Equatable {
    case invalidData(String)
    case invalidRoute(String)
    public var errorDescription: String? {
        switch self {
        case .invalidData(let message), .invalidRoute(let message): return message
        }
    }
}

public struct CityPack: Codable {
    public let schemaVersion: Int
    public let cityID: String
    public let cityName: String
    public let version: String
    public let dataAsOf: String?
    public let generatedAt: String
    public let isSample: Bool
    public let coverageNote: String
    public let disclaimer: String
    public let map: MapLayout
    public let districts: [District]
    public let lines: [MetroLine]
    public let stations: [Station]
    public let sources: [DataSource]
    public let coverageReview: CoverageReview?
    public let networkReview: NetworkReview?
    public let throughServices: [ThroughService]?
    public let mapContext: MapContext?
    /// District review is independent of station service collection.
    public var needsMetadata: Bool { !isSample && coverageReview?.districtsReviewed != true }
}

public struct NetworkReview: Codable {
    public let reviewedAt: String
    public let sourceIDs: [String]
    public let lineCount: Int
    public let stationCount: Int
    public let membershipCount: Int
}

public struct ThroughService: Codable {
    public let fromStationID: String
    public let toStationID: String
    public let lineIDs: [String]
    public let note: String
}

public struct CoverageReview: Codable {
    public let reviewer: String
    public let completeNetwork: Bool
    public let usageRightsConfirmed: Bool
    public let districtsReviewed: Bool
    public let reviewedAt: String
    public let sourceIDs: [String]
}

public struct MapLayout: Codable {
    public let width: Double
    public let height: Double
}

public struct DiagramPoint: Codable, Equatable {
    public let x: Double
    public let y: Double
}

public struct District: Codable, Identifiable {
    public let id: String
    public let name: String
    public let color: String
    public let polygon: [DiagramPoint]
    public let label: DiagramPoint
    public let note: String?
}

public struct MetroLine: Codable, Identifiable {
    public let id: String
    public let name: String
    public let shortName: String
    public let color: String
    public let stationIDs: [String]
    public let termini: [String]
    public let sourceIDs: [String]
    public let coverageNote: String?
    public let diagramPath: String?
    public let badgePosition: DiagramPoint?
}

public struct Station: Codable, Identifiable {
    public let id: String
    public let name: String
    public let aliases: [String]
    public let districtIDs: [String]
    public let districtNote: String?
    public let lineIDs: [String]
    public let diagram: DiagramPoint
    public let labelOffset: DiagramPoint
    public let labelAnchor: String?
    public let diagramMarkerPath: String?
    public let coordinate: GeoCoordinate?
    public let coordinateSourceIDs: [String]
    public let amapLocation: AmapLocation?
    public let serviceReview: StationServiceReview?
    public let serviceNotices: [ServiceNotice]?
    public let exits: [StationExit]
    public let timetables: [Timetable]
    public let sourceIDs: [String]
    public let updatedAt: String?
    public let note: String?
}

/// Provider-specific station identity and GCJ02 position; never pass as WGS84.
public struct AmapLocation: Codable, Equatable {
    public enum System: String, Codable { case gcj02 }
    public let poiID: String
    public let latitude: Double
    public let longitude: Double
    public let system: System
    public let sourceIDs: [String]
    public let updatedAt: String
    public var isValid: Bool {
        poiID.range(of: #"^B[A-Z0-9]+$"#, options: .regularExpression) != nil &&
        latitude.isFinite && longitude.isFinite &&
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

public struct StationExit: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let verifiedAt: String?
    public let coordinate: GeoCoordinate?
    public let sourceIDs: [String]
    public let updatedAt: String
}

public enum ServiceReviewStatus: String, Codable {
    case notCollected, partial, reviewed, conflict

    public var display: String {
        switch self {
        case .notCollected: return "尚未采集"
        case .partial: return "部分收录，仍有缺口"
        case .reviewed: return "已核验收录资料"
        case .conflict: return "存在冲突，待核对"
        }
    }
}

public struct StationServiceReview: Codable {
    public let timetableStatus: ServiceReviewStatus
    public let exitStatus: ServiceReviewStatus
    public let note: String?
    public let verifiedAt: String?
    public let timetableNote: String?
    public let exitNote: String?
}

/// Dated narrative conditions remain separate from exact station departure times.
public struct ServiceNotice: Codable, Identifiable {
    public let id: String
    public let text: String
    public let serviceDates: [String]
    public let validFrom: String?
    public let validThrough: String?
    public let sourceIDs: [String]
    public let verifiedAt: String
}

public struct Timetable: Codable, Identifiable {
    public let id: String
    public let lineID: String
    public let direction: String
    public let serviceDays: String
    public let validFrom: String?
    public let validThrough: String?
    public let first: ServiceTime?
    public let last: ServiceTime?
    public let serviceLabel: String?
    public let verifiedAt: String?
    public let lastDestination: String?
    public let note: String?
    public let sourceIDs: [String]
    public let updatedAt: String

    public func isExpired(on date: Date = Date()) -> Bool {
        guard let validThrough else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date) > validThrough
    }
}

public struct ServiceTime: Codable, Equatable {
    public let clock: String
    public let dayOffset: Int
    public init(clock: String, dayOffset: Int) throws {
        guard clock.range(of: #"^([01][0-9]|2[0-3]):[0-5][0-9]$"#, options: .regularExpression) != nil,
              (0...1).contains(dayOffset) else { throw MetroError.invalidData("首末班车时间格式错误") }
        self.clock = clock
        self.dayOffset = dayOffset
    }
    public var display: String { (dayOffset == 1 ? "次日 " : "") + clock }
    public var minutes: Int {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return -1 }
        return dayOffset * 1440 + parts[0] * 60 + parts[1]
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(clock: container.decode(String.self, forKey: .clock),
                      dayOffset: container.decode(Int.self, forKey: .dayOffset))
    }
}

public struct DataSource: Codable, Identifiable {
    public let id: String
    public let title: String
    public let url: String?
    public let sourcePublishedAt: String?
    public let accessedAt: String
    public let license: String
    public let note: String
}

/// v1 deliberately accepts only a known, explicit datum. Never relabel GCJ02/BD09 as WGS84.
public struct GeoCoordinate: Codable, Equatable {
    public enum System: String, Codable { case wgs84 }
    public let latitude: Double
    public let longitude: Double
    public let system: System
    public init(latitude: Double, longitude: Double, system: System) {
        self.latitude = latitude
        self.longitude = longitude
        self.system = system
    }
    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}


public struct DiagramRect: Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public func fits(width canvasWidth: Double, height canvasHeight: Double) -> Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 && width > 0 && height > 0 &&
        x + width <= canvasWidth && y + height <= canvasHeight
    }
}

public struct MapFocusArea: Codable, Identifiable {
    public let id: String
    public let title: String
    public let frame: DiagramRect
}

public struct ContextArea: Codable, Identifiable {
    public enum Kind: String, Codable { case neighbor, water, home, acrossWater }
    public let id: String
    public let name: String
    public let kind: Kind
    public let polygon: [DiagramPoint]
    public let label: DiagramPoint
    public let note: String
    public let sourceIDs: [String]
}

public struct ContextBoundary: Codable, Identifiable {
    public enum Kind: String, Codable { case city, region, coast }
    public let id: String
    public let kind: Kind
    public let points: [DiagramPoint]
    public let sides: [String]
    public let label: DiagramPoint?
    public let note: String
    public let sourceIDs: [String]
}

public struct ContextInset: Codable, Identifiable {
    public let id: String
    public let title: String
    public let note: String
    public let frame: DiagramRect
    public let areas: [ContextArea]
    public let sourceIDs: [String]
}

public struct ContextStationNote: Codable {
    public let stationID: String
    public let marker: String
    public let text: String
    public let sourceIDs: [String]
}

public struct ContextAnnotation: Codable, Identifiable {
    public let id: String
    public let text: String
    public let position: DiagramPoint
    public let fontSize: Double
    public let sourceIDs: [String]
}

public struct MapContext: Codable {
    public let reviewedAt: String
    public let note: String
    public let sourceIDs: [String]
    public let areas: [ContextArea]
    public let boundaries: [ContextBoundary]
    public let insets: [ContextInset]
    public let focusAreas: [MapFocusArea]
    public let stationNotes: [ContextStationNote]
    public let annotations: [ContextAnnotation]
    public let networkFrame: DiagramRect

    func validate(map: MapLayout, sourceIDs validSources: Set<String>, stationIDs: Set<String>) throws {
        func require(_ ok: Bool) throws {
            if !ok { throw MetroError.invalidData("周边地图资料不完整、越界或来源缺失") }
        }
        func sources(_ ids: [String]) -> Bool { !ids.isEmpty && Set(ids).isSubset(of: validSources) }
        func unique(_ ids: [String]) -> Bool { Set(ids).count == ids.count && ids.allSatisfy { !$0.isEmpty } }
        func valid(_ point: DiagramPoint) -> Bool { point.x.isFinite && point.y.isFinite }
        func area(_ a: ContextArea) throws {
            try require(!a.name.isEmpty && a.polygon.count >= 3 && a.polygon.allSatisfy(valid) && valid(a.label) && sources(a.sourceIDs))
        }
        try require(!reviewedAt.isEmpty && !note.isEmpty && sources(sourceIDs) && networkFrame.fits(width: map.width, height: map.height))
        try require(unique(areas.map(\.id)) && unique(boundaries.map(\.id)) && unique(insets.map(\.id)) && unique(focusAreas.map(\.id)))
        for a in areas { try area(a) }
        try require(unique(annotations.map(\.id)))
        for a in annotations { try require(!a.text.isEmpty && valid(a.position) && a.fontSize.isFinite && a.fontSize > 0 && sources(a.sourceIDs)) }
        for b in boundaries {
            try require(b.points.count >= 2 && b.points.allSatisfy(valid) && b.sides.count == 2 &&
                        b.sides.allSatisfy { !$0.isEmpty } && !b.note.isEmpty && sources(b.sourceIDs))
            if let p = b.label { try require(valid(p)) }
        }
        for i in insets {
            try require(!i.title.isEmpty && !i.note.isEmpty && sources(i.sourceIDs) && unique(i.areas.map(\.id)) && i.frame.fits(width: map.width, height: map.height))
            for a in i.areas { try area(a) }
        }
        for f in focusAreas { try require(!f.title.isEmpty && f.frame.fits(width: map.width, height: map.height)) }
        try require(unique(stationNotes.map(\.stationID)))
        for n in stationNotes { try require(stationIDs.contains(n.stationID) && !n.marker.isEmpty && !n.text.isEmpty && sources(n.sourceIDs)) }
    }
}


/// Compact display only; original records and their provenance remain in the city pack.
public enum TimetablePresentation {
    public static func rows(_ records: [Timetable]) -> [Timetable] {
        records.filter { candidate in
            guard candidate.serviceDays == "平日和周末", candidate.serviceLabel == "全程" else { return true }
            // Suppress a combined regular table only when BOTH daily tables carry
            // the same times and effective dates. Never infer an unknown service day.
            return !["工作日", "休息日"].allSatisfy { day in
                records.contains {
                    $0.lineID == candidate.lineID && $0.direction == candidate.direction &&
                    $0.serviceDays == day && ($0.serviceLabel == nil || $0.serviceLabel == "全程") &&
                    $0.first == candidate.first && $0.last == candidate.last &&
                    $0.validFrom == candidate.validFrom && $0.validThrough == candidate.validThrough &&
                    ($0.lastDestination == nil || $0.lastDestination == candidate.lastDestination)
                }
            }
        }.sorted {
            let left = order($0), right = order($1)
            if left != right { return left < right }
            return $0.id < $1.id
        }
    }

    public static func dayLabel(_ timetable: Timetable) -> String {
        switch timetable.serviceDays {
        case "节假日参考（具体适用日期未注明，以专项公告为准）": return "节假日"
        case "平日和周末": return "平日／周末"
        case "来源未注明适用日": return "适用日未注明"
        default: return timetable.serviceDays
        }
    }

    private static func order(_ timetable: Timetable) -> Int {
        if timetable.serviceLabel == "半程加班车" { return 10 }
        switch dayLabel(timetable) {
        case "工作日": return 0
        case "休息日": return 1
        case "节假日": return 2
        case "平日／周末": return 3
        default: return 4
        }
    }
}
