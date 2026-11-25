import Foundation
import MapKit

// Apple's routes are just lists of coordinates (no street ids), so we split the map
// into small grid cells. A rating belongs to a cell; a route's score is the average
// of the cells it passes through.
enum Grid {
    static let step = 0.0015   // degrees, about 165 m

    static func cellID(for c: CLLocationCoordinate2D) -> String {
        let la = Int((c.latitude / step).rounded(.down))
        let lo = Int((c.longitude / step).rounded(.down))
        return "\(la)_\(lo)"
    }

    /// Distinct cells along the route, in walking order
    static func cells(along route: WalkPath) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for point in samplePoints(of: route) {
            let id = cellID(for: point)
            if seen.insert(id).inserted { ordered.append(id) }
        }
        return ordered
    }

    /// A point roughly every `meters` along the route polyline
    static func samplePoints(of route: WalkPath, every meters: Double = 50) -> [CLLocationCoordinate2D] {
        let coords = route.coordinates
        let n = coords.count
        guard n > 0 else { return [] }

        var result = [coords[0]]
        var sinceLast = 0.0   // distance walked since the last sample, carried between segments

        for i in 1..<n {
            let a = coords[i - 1]
            let b = coords[i]
            let segment = CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            guard segment > 0 else { continue }

            var pos = meters - sinceLast
            while pos <= segment {
                let t = pos / segment
                result.append(CLLocationCoordinate2D(
                    latitude: a.latitude + (b.latitude - a.latitude) * t,
                    longitude: a.longitude + (b.longitude - a.longitude) * t))
                pos += meters
            }
            sinceLast = segment - (pos - meters)
        }

        if let last = coords.last { result.append(last) }
        return result
    }

    // Swift's hashValue changes on every launch; the demo seeder needs a stable one
    static func stableHash(_ text: String) -> Int {
        var h: UInt64 = 5381
        for byte in text.utf8 { h = (h &* 33) &+ UInt64(byte) }
        return Int(h % 1_000_003)
    }
}
