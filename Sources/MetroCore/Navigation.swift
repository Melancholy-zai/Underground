import Foundation

public enum MapProvider: String, CaseIterable, Identifiable {
    case amap, baidu
    public var id: String { rawValue }
    public var name: String { self == .amap ? "高德地图" : "百度地图" }
    public var scheme: String { self == .amap ? "iosamap" : "baidumap" }
}

public struct NavigationEndpoint {
    public let name: String
    public let coordinate: GeoCoordinate?
    public let amapLocation: AmapLocation?
    public init(name: String, coordinate: GeoCoordinate?, amapLocation: AmapLocation? = nil) {
        self.name = name; self.coordinate = coordinate; self.amapLocation = amapLocation
    }
}

public struct NavigationRequest {
    public let origin: NavigationEndpoint
    public let destination: NavigationEndpoint
    public let mode: TravelMode
    public let city: String
    public init(origin: NavigationEndpoint, destination: NavigationEndpoint, mode: TravelMode, city: String = "深圳") {
        self.origin = origin; self.destination = destination; self.mode = mode; self.city = city
    }
    public var usesNameMatching: Bool { origin.coordinate == nil || destination.coordinate == nil }
}

public enum NavigationURLBuilder {
    public static func url(for provider: MapProvider, request: NavigationRequest) throws -> URL {
        for endpoint in [request.origin, request.destination] {
            guard !endpoint.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  endpoint.coordinate?.isValid != false, endpoint.amapLocation?.isValid != false else {
                throw MetroError.invalidRoute("导航位置不完整或坐标无效")
            }
        }
        var components = URLComponents()
        components.scheme = provider.scheme
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String) { items.append(URLQueryItem(name: name, value: value)) }
        switch provider {
        case .amap:
            components.host = "path"
            add("sourceApplication", "深铁分区图")
            add("sname", request.origin.name)
            add("dname", request.destination.name)
            guard request.origin.amapLocation != nil || request.origin.coordinate != nil else {
                throw MetroError.invalidRoute("该起点暂无已核实的高德位置，请选择其他起点或使用百度地图")
            }
            if let point = request.origin.amapLocation {
                add("sid", point.poiID)
                add("slat", number(point.latitude)); add("slon", number(point.longitude))
                if let end = request.destination.amapLocation {
                    add("did", end.poiID)
                    add("dlat", number(end.latitude)); add("dlon", number(end.longitude))
                } else if request.destination.coordinate != nil {
                    // dev applies to both endpoints. Do not relabel a WGS84 exit as GCJ02.
                    throw MetroError.invalidRoute("该出口与起点的坐标格式不同，请选择车站作为终点")
                }
                add("dev", "0")
            } else if let point = request.origin.coordinate {
                add("slat", number(point.latitude)); add("slon", number(point.longitude))
                if let end = request.destination.coordinate {
                    add("dlat", number(end.latitude)); add("dlon", number(end.longitude))
                }
                // Keep the acquired WGS84 origin. Amap resolves the station's POI itself;
                // its GCJ02 position must not be included under dev=1.
                if let end = request.destination.amapLocation { add("did", end.poiID) }
                add("dev", "1")
            }
            add("t", request.mode == .transit ? "1" : "2")
            add("m", "0")
        case .baidu:
            components.host = "map"
            components.path = "/direction"
            add("origin", baiduEndpoint(request.origin))
            add("destination", baiduEndpoint(request.destination))
            add("region", request.city)
            add("mode", request.mode == .transit ? "transit" : "walking")
            add("coord_type", "wgs84")
            add("src", "ios.local.Underground")
        }
        components.queryItems = items
        guard let url = components.url else { throw MetroError.invalidRoute("无法生成地图链接") }
        return url
    }
    private static func number(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
    private static func baiduEndpoint(_ endpoint: NavigationEndpoint) -> String {
        guard let point = endpoint.coordinate else { return endpoint.name }
        return "name:\(endpoint.name)|latlng:\(number(point.latitude)),\(number(point.longitude))"
    }
}
