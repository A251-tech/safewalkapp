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

    /// Plain-words explanation of why there may be no location yet (shown on the Routes screen)
    var statusText: String {
        switch status {
        case .notDetermined:
            return "Location permission has not been given yet."
        case .denied, .restricted:
            return "Location is off for SafeWalk. Turn it on in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            return "Permission is on. Waiting for a GPS fix. In the simulator, choose a location with the paper-plane icon in Xcode."
        @unknown default:
            return "Checking your location."
        }
    }

    #if DEBUG
    /// Testing only: pretend the phone is at this spot (the simulator has no GPS).
    /// This does not exist in release builds.
    func useTestLocation(latitude: Double, longitude: Double) {
        location = CLLocation(latitude: latitude, longitude: longitude)
    }
    #endif

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

    // MARK: - Walk tracking

    /// True when "Location updates" is switched on under Signing & Capabilities > Background Modes
    var backgroundTrackingAvailable: Bool {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        return modes.contains("location")
    }

    /// Call when a walk starts: tighter updates, and keep going when the screen locks
    func beginWalkTracking() {
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        // Turning this on without the Background Modes capability crashes the app, so check first
        if backgroundTrackingAvailable {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        start()
    }

    /// Call when the walk ends: back to normal, battery-friendly tracking
    func endWalkTracking() {
        if backgroundTrackingAvailable {
            manager.allowsBackgroundLocationUpdates = false
            manager.showsBackgroundLocationIndicator = false
        }
        manager.pausesLocationUpdatesAutomatically = true
        manager.distanceFilter = 10
    }

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
