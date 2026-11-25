import Foundation
import Combine
import CoreLocation

// Helpers to turn a grid cell id ("la_lo") back into a square on the map
extension Grid {
    static func parts(of id: String) -> (la: Int, lo: Int)? {
        let pieces = id.split(separator: "_")
        guard pieces.count == 2, let la = Int(pieces[0]), let lo = Int(pieces[1]) else { return nil }
        return (la, lo)
    }

    /// The four corners of a cell, in drawing order
    static func corners(of id: String) -> [CLLocationCoordinate2D] {
        guard let p = parts(of: id) else { return [] }
        let south = Double(p.la) * step, north = Double(p.la + 1) * step
        let west = Double(p.lo) * step, east = Double(p.lo + 1) * step
        return [CLLocationCoordinate2D(latitude: south, longitude: west),
                CLLocationCoordinate2D(latitude: south, longitude: east),
                CLLocationCoordinate2D(latitude: north, longitude: east),
                CLLocationCoordinate2D(latitude: north, longitude: west)]
    }

    /// All cells in a square of (2 * radius + 1) cells around a point
    static func cells(around c: CLLocationCoordinate2D, radius: Int) -> [String] {
        guard let p = parts(of: cellID(for: c)) else { return [] }
        var result: [String] = []
        for la in (p.la - radius)...(p.la + radius) {
            for lo in (p.lo - radius)...(p.lo + radius) {
                result.append("\(la)_\(lo)")
            }
        }
        return result
    }
}

enum CellTint { case unrated, good, fair, poor }

// CONTROLLER: the Community tab. Loads the ratings around a point and saves new ones.
@MainActor
final class CommunityController: ObservableObject {
    @Published private(set) var cells: [String] = []
    @Published private(set) var scores: [String: CellScore] = [:]
    @Published var selectedCell: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var message: String?

    private let service = RatingService()
    static let radius = 4   // 9 x 9 cells, about 1.5 km across

    /// Cells to draw: the grid, plus the selected cell if it is outside the grid
    var drawCells: [String] {
        if let selected = selectedCell, !cells.contains(selected) { return cells + [selected] }
        return cells
    }

    func load(around center: CLLocationCoordinate2D) async {
        isLoading = true
        defer { isLoading = false }
        let grid = Grid.cells(around: center, radius: Self.radius)
        cells = grid
        do {
            scores = try await service.fetchScores(cells: grid)
            message = nil
        } catch {
            message = "Could not load ratings. Check your connection and Firestore rules."
        }
    }

    func select(_ coordinate: CLLocationCoordinate2D) {
        selectedCell = Grid.cellID(for: coordinate)
    }

    func tint(for id: String) -> CellTint {
        guard let score = scores[id], score.count > 0 else { return .unrated }
        let combined = score.safety.map { (score.lighting + score.crowd + $0) / 3 }
            ?? (score.lighting + score.crowd) / 2
        if combined >= 3.8 { return .good }
        if combined >= 3.0 { return .fair }
        return .poor
    }

    /// Saves one rating for the selected cell, then reloads that cell
    func submit(lighting: Int, crowd: Int, safety: Int) async -> Bool {
        guard let cell = selectedCell else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.submit(cellId: cell, lighting: lighting, crowd: crowd, safety: safety)
            let fresh = try await service.fetchScores(cells: [cell])
            scores[cell] = fresh[cell]
            message = nil
            return true
        } catch {
            message = "Could not save your rating. Check your connection and Firestore rules."
            return false
        }
    }
}
