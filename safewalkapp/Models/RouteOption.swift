/*import Foundation
import MapKit

// MODEL: one walking route the user can choose, with its community scores.
struct RouteOption: Identifiable {
    let id: String
    let route: WalkPath
    let title: String          // "Via College Avenue"
    let minutes: Int
    let distanceText: String   // "0.8 mi" or "1.2 km", depending on the phone's region
    let cells: [String]        // grid cells the route passes through

    var lighting: Double?      // nil = not enough ratings
    var crowd: Double?
    var reports = 0
    var label = ""             // "Shortest", "More lighting", ...

    var combined: Double? {
        guard let lighting, let crowd else { return nil }
        return (lighting + crowd) / 2
    }

    // Drives the red-tinted card in the design
    var isLowScore: Bool { (combined ?? 5) < 3.5 }

    var subtitle: String {
        label.isEmpty ? distanceText : "\(distanceText) · \(label)"
    }
}
*/
import Foundation
import MapKit

// MODEL: one walking route the user can choose, with its community scores.
struct RouteOption: Identifiable {
    let id: String
    let route: WalkPath
    let title: String          // "Via College Avenue"
    let minutes: Int
    let distanceText: String   // "0.8 mi" or "1.2 km", depending on the phone's region
    let cells: [String]        // grid cells the route passes through

    var lighting: Double?      // nil = not enough ratings
    var crowd: Double?
    var safety: Double?        // nil = nobody has rated safety here yet
    var reports = 0
    var label = ""             // "Shortest", "More lighting", ...

    // Average of lighting, crowd and (when it exists) safety
    var combined: Double? {
        guard let lighting, let crowd else { return nil }
        if let safety { return (lighting + crowd + safety) / 3 }
        return (lighting + crowd) / 2
    }

    // Drives the red-tinted card in the design
    var isLowScore: Bool { (combined ?? 5) < 3.5 }

    var subtitle: String {
        label.isEmpty ? distanceText : "\(distanceText) · \(label)"
    }
}
