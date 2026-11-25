import Foundation
import CoreLocation
import MapKit

// MODEL: the walk statuses. These exact strings are also allowed by the Firestore rules.
enum WalkStatus: String {
    case active
    case arrived
    case ended
    case missedCheckIn = "missed_checkin"
    case sos
}

// What the phone knows about the walk in progress.
// The shared copy lives in Firestore at walks/{id}; the id is a long random token and
// is also the private link that contacts open.
struct WalkSession: Identifiable {
    let id: String
    let destinationName: String
    let destination: CLLocationCoordinate2D
    let route: WalkPath
    let startedAt: Date
    let checkInInterval: TimeInterval
    let routePoints: [CLLocation]    // a point every ~20 m along the route
}

// What a contact sees of someone else's walk (read from walks/{id})
struct LiveWalk {
    let status: WalkStatus
    let destinationName: String
    let coordinate: CLLocationCoordinate2D?
    let lastUpdated: Date?
    let nextCheckInAt: Date?
}
