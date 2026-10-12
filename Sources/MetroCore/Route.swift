import Foundation

public enum RouteOrigin: Equatable {
    case currentLocation
    case station(String)
}

public enum RouteDestination: Equatable {
    case station(String)
    case exit(stationID: String, exitID: String)
    public var stationID: String {
        switch self {
        case .station(let id), .exit(let id, _): return id
        }
    }
}

public enum TravelMode: String, CaseIterable {
    case transit, walking
    public var title: String { self == .transit ? "公共交通" : "步行到站" }
}

public struct RouteSelection: Equatable {
    public var origin: RouteOrigin = .currentLocation
    public var destination: RouteDestination?
    public var mode: TravelMode = .transit
    public init() {}
    public var canSwap: Bool {
        if case .station = origin, case .station? = destination { return true }
        return false
    }
    public mutating func swap() {
        guard case .station(let start) = origin, case .station(let end)? = destination else { return }
        origin = .station(end)
        destination = .station(start)
    }
    public func validate() throws {
        guard let destination else { throw MetroError.invalidRoute("请先选择终点站") }
        if case .station(let start) = origin, start == destination.stationID {
            throw MetroError.invalidRoute("起点和终点是同一站，请重新选择")
        }
    }
}
