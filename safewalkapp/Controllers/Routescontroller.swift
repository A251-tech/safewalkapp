/*import Foundation
import Combine
import MapKit

// CONTROLLER: finds the routes, scores them from community ratings, tracks the selection.
@MainActor
final class RoutesController: ObservableObject {
    @Published private(set) var routes: [RouteOption] = []
    @Published var selectedID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isSeeding = false
    @Published private(set) var hasDemoData = false
    @Published var errorMessage: String?

    private let routeService = RouteService()
    private let ratingService = RatingService()
    private let distanceFormatter = MKDistanceFormatter()

    var selectedRoute: RouteOption? { routes.first { $0.id == selectedID } }

    // MARK: - Loading

    func load(from start: CLLocationCoordinate2D, to destination: MKMapItem) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let found = try await routeService.walkingRoutes(from: start, to: destination)
            // Sorted by time, quickest first. Show at most 3.
            let sorted = found.sorted { $0.expectedTravelTime < $1.expectedTravelTime }.prefix(3)

            routes = sorted.enumerated().map { index, route in
                RouteOption(
                    id: "route-\(index)",
                    route: route,
                    title: route.name.isEmpty ? "Route \(index + 1)" : "Via \(route.name)",
                    minutes: max(1, Int((route.expectedTravelTime / 60).rounded())),
                    distanceText: distanceFormatter.string(fromDistance: route.distance),
                    cells: Grid.cells(along: route))
            }

            if routes.isEmpty {
                errorMessage = "No walking route found to this destination."
                return
            }
            await applyScores()
            selectDefault()
        } catch {
            routes = []
            errorMessage = "Could not find walking routes. Check your connection and try again."
        }
    }

    func select(_ id: String) { selectedID = id }

    // MARK: - Scoring

    /// Reads the ratings for every cell on every route and fills in each route's scores
    private func applyScores() async {
        let allCells = Array(Set(routes.flatMap { $0.cells }))
        do {
            let scores = try await ratingService.fetchScores(cells: allCells)
            hasDemoData = scores.values.contains { $0.hasDemo }

            for i in routes.indices {
                let cells = routes[i].cells
                let rated = cells.compactMap { scores[$0] }
                routes[i].reports = rated.reduce(0) { $0 + $1.count }

                // Need ratings on at least 30% of the route, otherwise say "no data"
                let coverage = cells.isEmpty ? 0 : Double(rated.count) / Double(cells.count)
                if rated.isEmpty || coverage < 0.3 {
                    routes[i].lighting = nil
                    routes[i].crowd = nil
                } else {
                    routes[i].lighting = rated.map(\.lighting).reduce(0, +) / Double(rated.count)
                    routes[i].crowd = rated.map(\.crowd).reduce(0, +) / Double(rated.count)
                }
            }
        } catch {
            errorMessage = "Could not load community ratings."
        }
        assignLabels()
    }

    private func assignLabels() {
        guard routes.count > 1 else {
            for i in routes.indices { routes[i].label = "" }
            return
        }
        let fastest = routes.indices.min { routes[$0].route.expectedTravelTime < routes[$1].route.expectedTravelTime }
        let bestLit = routes.indices
            .filter { routes[$0].combined != nil }
            .max { (routes[$0].combined ?? 0) < (routes[$1].combined ?? 0) }

        for i in routes.indices {
            if i == fastest && i == bestLit { routes[i].label = "Shortest and best lit" }
            else if i == fastest { routes[i].label = "Shortest" }
            else if i == bestLit { routes[i].label = "More lighting" }
            else { routes[i].label = "" }
        }
    }

    // Pre-select the best rated route, or the quickest one when there are no ratings
    private func selectDefault() {
        let best = routes.filter { $0.combined != nil }
            .max { ($0.combined ?? 0) < ($1.combined ?? 0) }
        selectedID = (best ?? routes.first)?.id
    }

    // MARK: - Demo data (debug builds only show the buttons)

    /// Writes sample ratings along the routes just found, so the scores differ.
    /// Quickest route: dim and quiet. Other routes: well lit and busy. Shared cells: in between.
    func seedDemo() async {
        guard !routes.isEmpty else { return }
        isSeeding = true
        defer { isSeeding = false }

        let fastestID = routes.min { $0.route.expectedTravelTime < $1.route.expectedTravelTime }?.id
        var usage: [String: Int] = [:]
        for route in routes { for cell in Set(route.cells) { usage[cell, default: 0] += 1 } }

        var profiles: [String: DemoProfile] = [:]
        for route in routes {
            for cell in Set(route.cells) {
                if routes.count == 1 {
                    profiles[cell] = DemoProfile(lighting: 3.8, crowd: 3.5)
                } else if (usage[cell] ?? 0) > 1 {
                    profiles[cell] = DemoProfile(lighting: 4.0, crowd: 3.8)
                } else if route.id == fastestID {
                    profiles[cell] = DemoProfile(lighting: 2.6, crowd: 2.4)
                } else {
                    profiles[cell] = DemoProfile(lighting: 4.6, crowd: 4.2)
                }
            }
        }

        do {
            try await ratingService.seedDemo(profiles: profiles)
            errorMessage = nil
            await applyScores()
            selectDefault()
        } catch {
            errorMessage = "Could not write demo ratings. Check your Firestore rules."
        }
    }

    func clearDemo() async {
        isSeeding = true
        defer { isSeeding = false }
        do {
            try await ratingService.clearDemo()
            errorMessage = nil
            await applyScores()
            selectDefault()
        } catch {
            errorMessage = "Could not clear demo ratings."
        }
    }
}
*/
import Foundation
import Combine
import MapKit

// CONTROLLER: finds the routes, scores them from community ratings, tracks the selection.
@MainActor
final class RoutesController: ObservableObject {
    @Published private(set) var routes: [RouteOption] = []
    @Published var selectedID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isSeeding = false
    @Published private(set) var hasDemoData = false
    @Published var errorMessage: String?

    private let routeService = RouteService()
    private let ratingService = RatingService()
    private let distanceFormatter = MKDistanceFormatter()

    var selectedRoute: RouteOption? { routes.first { $0.id == selectedID } }

    // MARK: - Loading

    func load(from start: CLLocationCoordinate2D, to destination: MKMapItem) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let found = try await routeService.walkingRoutes(from: start, to: destination)
            // Sorted by time, quickest first. Show at most 3.
            let sorted = found.sorted { $0.expectedTravelTime < $1.expectedTravelTime }.prefix(3)

            routes = sorted.enumerated().map { index, route in
                RouteOption(
                    id: "route-\(index)",
                    route: route,
                    title: route.name.isEmpty ? "Route \(index + 1)" : "Via \(route.name)",
                    minutes: max(1, Int((route.expectedTravelTime / 60).rounded())),
                    distanceText: distanceFormatter.string(fromDistance: route.distance),
                    cells: Grid.cells(along: route))
            }

            if routes.isEmpty {
                errorMessage = "No walking route found to this destination."
                return
            }
            await applyScores()
            selectDefault()
        } catch {
            routes = []
            errorMessage = "Could not find walking routes. Check your connection and try again."
        }
    }

    func select(_ id: String) { selectedID = id }

    // MARK: - Scoring

    /// Reads the ratings for every cell on every route and fills in each route's scores
    private func applyScores() async {
        let allCells = Array(Set(routes.flatMap { $0.cells }))
        do {
            let scores = try await ratingService.fetchScores(cells: allCells)
            hasDemoData = scores.values.contains { $0.hasDemo }

            for i in routes.indices {
                let cells = routes[i].cells
                let rated = cells.compactMap { scores[$0] }
                routes[i].reports = rated.reduce(0) { $0 + $1.count }

                // Need ratings on at least 30% of the route, otherwise say "no data"
                let coverage = cells.isEmpty ? 0 : Double(rated.count) / Double(cells.count)
                if rated.isEmpty || coverage < 0.3 {
                    routes[i].lighting = nil
                    routes[i].crowd = nil
                    routes[i].safety = nil
                } else {
                    routes[i].lighting = rated.map(\.lighting).reduce(0, +) / Double(rated.count)
                    routes[i].crowd = rated.map(\.crowd).reduce(0, +) / Double(rated.count)
                    let safetyValues = rated.compactMap(\.safety)
                    routes[i].safety = safetyValues.isEmpty
                        ? nil
                        : safetyValues.reduce(0, +) / Double(safetyValues.count)
                }
            }
        } catch {
            errorMessage = "Could not load community ratings."
        }
        assignLabels()
    }

    private func assignLabels() {
        guard routes.count > 1 else {
            for i in routes.indices { routes[i].label = "" }
            return
        }
        let fastest = routes.indices.min { routes[$0].route.expectedTravelTime < routes[$1].route.expectedTravelTime }
        let bestLit = routes.indices
            .filter { routes[$0].combined != nil }
            .max { (routes[$0].combined ?? 0) < (routes[$1].combined ?? 0) }

        for i in routes.indices {
            if i == fastest && i == bestLit { routes[i].label = "Shortest and best lit" }
            else if i == fastest { routes[i].label = "Shortest" }
            else if i == bestLit { routes[i].label = "More lighting" }
            else { routes[i].label = "" }
        }
    }

    // Pre-select the best rated route, or the quickest one when there are no ratings
    private func selectDefault() {
        let best = routes.filter { $0.combined != nil }
            .max { ($0.combined ?? 0) < ($1.combined ?? 0) }
        selectedID = (best ?? routes.first)?.id
    }

    // MARK: - Demo data (debug builds only show the buttons)

    /// Writes sample ratings along the routes just found, so the scores differ.
    /// Quickest route: dim and quiet. Other routes: well lit and busy. Shared cells: in between.
    func seedDemo() async {
        guard !routes.isEmpty else { return }
        isSeeding = true
        defer { isSeeding = false }

        let fastestID = routes.min { $0.route.expectedTravelTime < $1.route.expectedTravelTime }?.id
        var usage: [String: Int] = [:]
        for route in routes { for cell in Set(route.cells) { usage[cell, default: 0] += 1 } }

        var profiles: [String: DemoProfile] = [:]
        for route in routes {
            for cell in Set(route.cells) {
                if routes.count == 1 {
                    profiles[cell] = DemoProfile(lighting: 3.8, crowd: 3.5)
                } else if (usage[cell] ?? 0) > 1 {
                    profiles[cell] = DemoProfile(lighting: 4.0, crowd: 3.8)
                } else if route.id == fastestID {
                    profiles[cell] = DemoProfile(lighting: 2.6, crowd: 2.4)
                } else {
                    profiles[cell] = DemoProfile(lighting: 4.6, crowd: 4.2)
                }
            }
        }

        do {
            try await ratingService.seedDemo(profiles: profiles)
            errorMessage = nil
            await applyScores()
            selectDefault()
        } catch {
            errorMessage = "Could not write demo ratings. Check your Firestore rules."
        }
    }

    func clearDemo() async {
        isSeeding = true
        defer { isSeeding = false }
        do {
            try await ratingService.clearDemo()
            errorMessage = nil
            await applyScores()
            selectDefault()
        } catch {
            errorMessage = "Could not clear demo ratings."
        }
    }
}
