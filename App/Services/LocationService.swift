import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject {
    private var manager: CLLocationManager?
    private var pending: CheckedContinuation<GeoCoordinate, Error>?
    private var timeout: Task<Void, Never>?
    private var gate = RequestGate()

    func request() async throws -> GeoCoordinate {
        cancel()
        let token = gate.begin()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                pending = continuation
                let manager = CLLocationManager()
                self.manager = manager
                manager.delegate = self
                manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                timeout = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(20))
                    guard !Task.isCancelled else { return }
                    self?.finish(.failure(MetroError.invalidRoute("获取位置超时，请重试或手动选站")), token: token)
                }
                switch manager.authorizationStatus {
                case .notDetermined: manager.requestWhenInUseAuthorization()
                case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
                case .denied, .restricted: finish(.failure(MetroError.invalidRoute("未获得定位权限。可手动选站，或在系统设置中允许定位")), token: token)
                @unknown default: finish(.failure(MetroError.invalidRoute("定位暂不可用，请手动选站")), token: token)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(.failure(CancellationError()), token: token) }
        }
    }
    func cancel() {
        gate.cancel()
        finish(.failure(CancellationError()))
    }
    private func finish(_ result: Result<GeoCoordinate, Error>, token: UUID? = nil) {
        if let token, !gate.finish(token) { return }
        gate.cancel()
        timeout?.cancel(); timeout = nil
        manager?.delegate = nil
        manager?.stopUpdatingLocation(); manager = nil
        let continuation = pending; pending = nil
        continuation?.resume(with: result)
    }
}

// CoreLocation delivers on the manager's creation run loop (main here). Explicitly
// hop to MainActor for Swift concurrency, and ignore callbacks from a replaced manager.
extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self, manager === self.manager, self.pending != nil else { return }
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
            case .denied, .restricted: self.finish(.failure(MetroError.invalidRoute("定位被拒绝，可继续手动选择起点")))
            default: break
            }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self, manager === self.manager else { return }
            guard let location = locations.last(where: {
                $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 3000 && abs($0.timestamp.timeIntervalSinceNow) < 60
            }) else {
                self.finish(.failure(MetroError.invalidRoute("未取得足够可靠的位置，请重试或手动选站"))); return
            }
            self.finish(.success(GeoCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, system: .wgs84)))
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, manager === self.manager else { return }
            self.finish(.failure(MetroError.invalidRoute("定位失败：\(error.localizedDescription)。可继续手动选站")))
        }
    }
}
