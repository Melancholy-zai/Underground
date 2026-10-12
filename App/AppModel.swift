import SwiftUI
import UIKit

@MainActor
final class AppModel: ObservableObject {
    enum Tab: Hashable { case map, route, about }
    struct MapCommand: Encodable {
        let id = UUID().uuidString
        let kind: String
        var target: String? = nil
    }
    struct AlertMessage: Identifiable { let id = UUID(); let text: String }
    @Published var tab: Tab = .map
    @Published private(set) var city: LoadedCity?
    @Published private(set) var loadError: String?
    @Published var selectedLineID: String?
    @Published var selectedStationID: String?
    @Published var detailStation: Station?
    @Published var command = MapCommand(kind: "reset")
    @Published var route = RouteSelection() { didSet { if oldValue != route { cancelNavigation() } } }
    @Published var alert: AlertMessage?
    @Published private(set) var locating = false
    @Published private(set) var locationStatus = "尚未请求定位"
    private let locationService = LocationService()
    private var navigationTask: Task<Void, Never>?
    private var requestID = UUID()
    var repository: CityRepository? { city?.repository }
    init() { reload() }

    func reload() {
        do { city = try CityPackLoader.load(); loadError = nil }
        catch { city = nil; loadError = error.localizedDescription }
    }
    func toggleLine(_ id: String) {
        guard repository?.line(id) != nil else { return }
        selectedStationID = nil
        selectedLineID = selectedLineID == id ? nil : id
    }
    func selectStation(_ station: Station, focus: Bool = false) {
        selectedStationID = station.id
        if focus { selectedLineID = nil; command = MapCommand(kind: "focus", target: station.id) }
        detailStation = station
    }
    func setOrigin(_ station: Station) { route.origin = .station(station.id); detailStation = nil; tab = .route }
    func setDestination(_ station: Station) { route.destination = .station(station.id); route.mode = .transit; detailStation = nil; tab = .route }
    func walkTo(_ station: Station, exit: StationExit? = nil) {
        route.origin = .currentLocation
        route.destination = exit.map { .exit(stationID: station.id, exitID: $0.id) } ?? .station(station.id)
        route.mode = .walking; detailStation = nil; tab = .route
    }
    func originTitle() -> String {
        switch route.origin { case .currentLocation: return "当前位置"; case .station(let id): return repository?.station(id)?.name ?? "站点不可用" }
    }
    func destinationTitle() -> String {
        guard let destination = route.destination, let station = repository?.station(destination.stationID) else { return "选择终点站" }
        if case .exit(_, let exitID) = destination, let exit = station.exits.first(where: { $0.id == exitID }) { return station.name + " · " + exit.name }
        return station.name
    }
    func cancelNavigation() {
        requestID = UUID()
        navigationTask?.cancel(); navigationTask = nil
        locationService.cancel()
        if locating { locationStatus = "定位已取消，可重新获取" }
        locating = false
    }
    func locateOnly() { beginNavigation(provider: nil) }
    func openMap(_ provider: MapProvider) { beginNavigation(provider: provider) }

    private func beginNavigation(provider: MapProvider?) {
        guard let repository else { return }
        if let provider {
            do { try route.validate() } catch { alert = AlertMessage(text: error.localizedDescription); return }
            guard let scheme = URL(string: provider.scheme + "://"), UIApplication.shared.canOpenURL(scheme) else {
                alert = AlertMessage(text: "未安装或无法打开\(provider.name)，请安装后重试，或选择另一地图 App。"); return
            }
        }
        cancelNavigation()
        let snapshot = route, token = requestID
        navigationTask = Task { [weak self] in
            guard let self else { return }
            do {
                var location: GeoCoordinate?
                if snapshot.origin == .currentLocation {
                    self.locating = true; self.locationStatus = "正在获取当前位置…"
                    location = try await self.locationService.request()
                    try Task.checkCancellation()
                    guard self.requestID == token, self.route == snapshot else { return }
                    self.locating = false; self.locationStatus = "已获取位置；规划时会重新获取"
                }
                guard let provider else { return }
                let request = try repository.navigationRequest(route: snapshot, location: location)
                let url = try NavigationURLBuilder.url(for: provider, request: request)
                guard self.requestID == token, self.route == snapshot, !Task.isCancelled else { return }
                let opened = await UIApplication.shared.open(url)
                if !opened { self.alert = AlertMessage(text: "\(provider.name)未能打开，请重试或选择另一地图 App。") }
            } catch is CancellationError {
                // Editing the route explicitly invalidates pending location work.
            } catch {
                guard self.requestID == token else { return }
                self.locating = false; self.locationStatus = error.localizedDescription
                self.alert = AlertMessage(text: error.localizedDescription)
            }
        }
    }
}
