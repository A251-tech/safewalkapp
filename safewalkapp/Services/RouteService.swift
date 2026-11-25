import Foundation
import MapKit

// SERVICE: asks Apple Maps for walking routes.
// Apple often returns only one route for a short walk. When that happens we also ask for
// routes that pass through a point to the left and to the right of the straight line,
// so the user always has something to compare.
final class RouteService {
    private enum RouteError: Error { case none }

    func walkingRoutes(from start: CLLocationCoordinate2D, to destination: MKMapItem) async throws -> [WalkPath] {
        let source = Self.mapItem(at: start)
        let direct = try await calculate(from: source, to: destination, alternates: true)

        var paths = direct.map { WalkPath(route: $0) }
        guard let shortest = paths.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else {
            return []
        }

        if paths.count < 3 {
            let waypoints = Self.detourWaypoints(from: start, to: destination.mapCoordinate)
            if waypoints.count == 2 {
                // Both detours are requested at the same time, so it costs no extra waiting
                async let left = try? detourPath(from: source, via: waypoints[0], to: destination)
                async let right = try? detourPath(from: source, via: waypoints[1], to: destination)
                let candidates = [await left, await right].compactMap { $0 }

                for detour in candidates where paths.count < 3 {
                    let tooLong = detour.distance > shortest.distance * 1.6 + 200
                    let sameAsExisting = paths.contains { Self.overlap($0, detour) > 0.8 }
                    if !tooLong && !sameAsExisting { paths.append(detour) }
                }
            }
        }
        return paths
    }

    // MARK: - Helpers

    private func calculate(from source: MKMapItem, to destination: MKMapItem,
                           alternates: Bool) async throws -> [MKRoute] {
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = .walking
        request.requestsAlternateRoutes = alternates
        return try await MKDirections(request: request).calculate().routes
    }

    private func detourPath(from source: MKMapItem, via waypoint: CLLocationCoordinate2D,
                            to destination: MKMapItem) async throws -> WalkPath {
        let middle = Self.mapItem(at: waypoint)
        let firstLeg = try await calculate(from: source, to: middle, alternates: false)
        let secondLeg = try await calculate(from: middle, to: destination, alternates: false)
        guard let a = firstLeg.first, let b = secondLeg.first else { throw RouteError.none }
        return WalkPath(joining: a, and: b)
    }

    /// Two points, one on each side of the straight line, 30% of the trip length away from its middle
    private static func detourWaypoints(from a: CLLocationCoordinate2D,
                                        to b: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        let midLat = (a.latitude + b.latitude) / 2
        let midLon = (a.longitude + b.longitude) / 2
        let dLat = b.latitude - a.latitude
        let dLon = b.longitude - a.longitude
        let side = 0.3
        return [
            CLLocationCoordinate2D(latitude: midLat - dLon * side, longitude: midLon + dLat * side),
            CLLocationCoordinate2D(latitude: midLat + dLon * side, longitude: midLon - dLat * side)
        ]
    }

    /// Share of map cells two paths have in common (1 = the same way)
    private static func overlap(_ x: WalkPath, _ y: WalkPath) -> Double {
        let a = Set(Grid.cells(along: x))
        let b = Set(Grid.cells(along: y))
        guard !a.isEmpty, !b.isEmpty else { return 1 }
        return Double(a.intersection(b).count) / Double(min(a.count, b.count))
    }

    // iOS 26 replaced init(placemark:) with init(location:address:); keep older iOS working too
    private static func mapItem(at coordinate: CLLocationCoordinate2D) -> MKMapItem {
        if #available(iOS 26.0, *) {
            return MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                             address: nil)
        } else {
            return MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }
    }
}
