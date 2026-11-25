import Foundation
import MapKit

// One instruction along a path ("Turn left onto College Road")
struct PathStep {
    let instructions: String
    let distance: CLLocationDistance
}

// MODEL: a walking path. It is either one Apple Maps route, or two Apple Maps routes
// joined at a waypoint (used to offer a different way when Apple returns only one).
struct WalkPath {
    let name: String
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let steps: [PathStep]
    let coordinates: [CLLocationCoordinate2D]

    var polyline: MKPolyline { MKPolyline(coordinates: coordinates, count: coordinates.count) }

    init(route: MKRoute) {
        name = route.name
        distance = route.distance
        expectedTravelTime = route.expectedTravelTime
        steps = route.steps.map { PathStep(instructions: $0.instructions, distance: $0.distance) }
        coordinates = Self.coordinates(of: route.polyline)
    }

    /// Two legs joined end to start (start -> waypoint, waypoint -> destination)
    init(joining first: MKRoute, and second: MKRoute) {
        name = ""
        distance = first.distance + second.distance
        expectedTravelTime = first.expectedTravelTime + second.expectedTravelTime

        // Drop the "arrive" step of the first leg and the "start" step of the second
        let firstSteps = first.steps.dropLast()
        let secondSteps = second.steps.dropFirst()
        steps = (Array(firstSteps) + Array(secondSteps))
            .map { PathStep(instructions: $0.instructions, distance: $0.distance) }

        coordinates = Self.coordinates(of: first.polyline)
            + Self.coordinates(of: second.polyline).dropFirst()
    }

    private static func coordinates(of line: MKPolyline) -> [CLLocationCoordinate2D] {
        let count = line.pointCount
        guard count > 0 else { return [] }
        var result = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: count)
        line.getCoordinates(&result, range: NSRange(location: 0, length: count))
        return result
    }
}
