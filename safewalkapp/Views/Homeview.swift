import SwiftUI
import MapKit

// "Where to tonight?" - destination search + map + Compare routes button
struct HomeView: View {
    @EnvironmentObject private var auth: AuthController
    @EnvironmentObject private var contacts: ContactController
    @EnvironmentObject private var location: LocationService
    @StateObject private var search = DestinationController()
    @Binding var selectedTab: AppTab

    @FocusState private var searchFocused: Bool
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showRoutesNotice = false

    private var needsContacts: Bool { contacts.hasLoaded && contacts.contacts.isEmpty }
    private var showSuggestions: Bool { searchFocused && !search.suggestions.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(alignment: .leading, spacing: 8) {
                    Text("Where to tonight?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Theme.navy)
                    Text(greeting)
                        .font(.system(size: 17))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.top, 12)

                if needsContacts { addContactPrompt }

                searchField

                if let message = search.errorMessage {
                    MessageBanner(error: message, info: nil)
                }
                if location.isDenied { locationDeniedBanner }

                if showSuggestions {
                    suggestionList
                } else {
                    mapView
                }

                if let item = search.destination { destinationCard(item) }

                PrimaryButton(title: "Compare walking routes",
                              isEnabled: search.destination != nil && !needsContacts) {
                    // NEXT STEP: navigate to the Routes screen with search.destination
                    showRoutesNotice = true
                }

                privacyNote
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { location.start() }
        .onChange(of: location.location) { _, newValue in
            if let coordinate = newValue?.coordinate { search.updateRegion(around: coordinate) }
        }
        .onChange(of: search.destination) { _, _ in fitCamera() }
        .alert("Routes screen is next", isPresented: $showRoutesNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We'll build route comparison in the next step.")
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Text("SafeWalk")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Theme.navy)
            Spacer()
            // The shield doubles as the account menu (sign out lives here)
            Menu {
                if !auth.displayName.isEmpty { Text(auth.displayName) }
                Button("Sign out", role: .destructive) { auth.signOut() }
            } label: {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.navy)
            }
            .accessibilityLabel("Account menu")
        }
        .padding(.top, 8)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        let first = auth.displayName.split(separator: " ").first.map(String.init)
        return first.map { "\(part), \($0)" } ?? part
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundColor(Theme.navy)
            TextField("Search destination", text: $search.query)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .foregroundColor(Theme.navy)
                .onSubmit { Task { await search.searchTopResult() } }
            if search.isSearching {
                ProgressView()
            } else if !search.query.isEmpty {
                Button { search.clear() } label: {
                    Image(systemName: "xmark").foregroundColor(Theme.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(Theme.field)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.fieldBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(search.suggestions, id: \.self) { suggestion in
                Button {
                    Task {
                        await search.select(suggestion)
                        searchFocused = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle").foregroundColor(Theme.navy)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.navy)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                if suggestion != search.suggestions.last {
                    Divider().overlay(Theme.fieldBorder)
                }
            }
        }
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var mapView: some View {
        Map(position: $camera) {
            UserAnnotation()
            if let item = search.destination {
                Marker(item.name ?? "Destination", coordinate: item.placemark.coordinate)
                    .tint(Theme.navy)
            }
        }
        .mapControls { MapUserLocationButton() }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.fieldBorder, lineWidth: 1))
    }

    private func destinationCard(_ item: MKMapItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 20))
                .foregroundColor(Theme.navy)
                .frame(width: 52, height: 52)
                .background(Theme.field)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "Destination")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.navy)
                Text(distanceText(to: item))
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func distanceText(to item: MKMapItem) -> String {
        guard let here = location.location else { return "Walking destination" }
        let target = CLLocation(latitude: item.placemark.coordinate.latitude,
                                longitude: item.placemark.coordinate.longitude)
        let miles = here.distance(from: target) / 1609.34
        return String(format: "%.1f mi from you", miles)
    }

    private var addContactPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "person.badge.plus").foregroundColor(Theme.navy)
                Text("Add someone to your circle first")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.navy)
            }
            Text("A walk shares your location with your trusted circle, so add at least one contact before you start.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
            Button("Go to Circle") { selectedTab = .circle }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.navy)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var locationDeniedBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            MessageBanner(error: "Location is off. SafeWalk needs it to plan and share your walk.", info: nil)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(Theme.navy)
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock").foregroundColor(Theme.navy)
            Text("Your location is private until you start a walk. Sharing ends when your walk ends.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // Zoom the map so both you and the destination are visible
    private func fitCamera() {
        guard let dest = search.destination?.placemark.coordinate else { return }
        guard let me = location.location?.coordinate else {
            camera = .region(MKCoordinateRegion(center: dest,
                                                latitudinalMeters: 800, longitudinalMeters: 800))
            return
        }
        let center = CLLocationCoordinate2D(latitude: (me.latitude + dest.latitude) / 2,
                                            longitude: (me.longitude + dest.longitude) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max(abs(me.latitude - dest.latitude) * 1.6, 0.006),
            longitudeDelta: max(abs(me.longitude - dest.longitude) * 1.6, 0.006))
        camera = .region(MKCoordinateRegion(center: center, span: span))
    }
}
