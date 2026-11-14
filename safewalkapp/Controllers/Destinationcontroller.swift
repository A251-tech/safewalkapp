//
// import Foundation
import Combine
import MapKit
import CoreLocation

// CONTROLLER: destination search (suggestions while typing + final result).
@MainActor
final class DestinationController: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet {
            if suppressNextQuery { suppressNextQuery = false; return }
            if query.isEmpty { suggestions = [] }
            completer.queryFragment = query
        }
    }
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []
    @Published private(set) var destination: MKMapItem?
    @Published private(set) var isSearching = false
    @Published var errorMessage: String?

    private let completer = MKLocalSearchCompleter()
    private var suppressNextQuery = false
    private var searchRegion: MKCoordinateRegion?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Bias search results toward where the user is (e.g. the campus)
    func updateRegion(around coordinate: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(center: coordinate,
                                        latitudinalMeters: 5000, longitudinalMeters: 5000)
        searchRegion = region
        completer.region = region
    }

    // User tapped a suggestion
    func select(_ completion: MKLocalSearchCompletion) async {
        await run(MKLocalSearch.Request(completion: completion), title: completion.title)
    }

    // User pressed Search on the keyboard
    func searchTopResult() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        if let searchRegion { request.region = searchRegion }
        await run(request, title: text)
    }

    func clear() {
        query = ""
        suggestions = []
        destination = nil
        errorMessage = nil
    }

    private func run(_ request: MKLocalSearch.Request, title: String) async {
        errorMessage = nil
        isSearching = true
        defer { isSearching = false }
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                errorMessage = "No places found. Try a different search."
                return
            }
            destination = item
            suggestions = []
            suppressNextQuery = true
            query = item.name ?? title
        } catch {
            errorMessage = "Search failed. Check your connection and try again."
        }
    }

    // MARK: - MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = Array(completer.results.prefix(5))
        Task { @MainActor in self.suggestions = results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Suggestions are optional, so a failure here is silent.
    }
}
