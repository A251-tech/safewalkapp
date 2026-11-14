import Foundation
import Combine
import CoreLocation
 
// SERVICE: wraps CLLocationManager. Later the walk feature will reuse this
// for continuous updates, background mode and geofencing.
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var status: CLAuthorizationStatus
 
    private let manager = CLLocationManager()
 
    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10   // meters
    }
 
    var isDenied: Bool { status == .denied || status == .restricted }
 
    // Call when the Walk tab appears
    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }
 
    func stop() { manager.stopUpdatingLocation() }
 
    // MARK: - CLLocationManagerDelegate
 
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in
            self.status = newStatus
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }
 
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in self.location = latest }
    }
 
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignored for now; a failed fix just means we keep the last known location.
    }
}
 
