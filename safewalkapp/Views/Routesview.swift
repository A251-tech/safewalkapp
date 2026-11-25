/*import SwiftUI
import MapKit
import FirebaseAuth

// "Choose a route": map with the options drawn on it + community-rated route cards
struct RoutesView: View {
    let destination: MKMapItem

    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var contacts: ContactController
    @EnvironmentObject private var auth: AuthController
    @EnvironmentObject private var walk: WalkController
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = RoutesController()

    @State private var camera: MapCameraPosition = .automatic

    private var hasLocation: Bool { location.location != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                breadcrumb
                mapView
                content
                #if DEBUG
                demoTools
                #endif
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Choose a route")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { startBar }
        // Runs once the first GPS fix arrives
        .task(id: hasLocation) { await loadIfNeeded() }
        .onChange(of: controller.routes.count) { _, _ in fitCamera() }
    }

    // MARK: - Pieces

    private var breadcrumb: some View {
        HStack(spacing: 8) {
            Text("Your location")
                .foregroundColor(Theme.textSecondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
            Text(destination.name ?? "Destination")
                .fontWeight(.semibold)
                .foregroundColor(Theme.navy)
                .lineLimit(1)
        }
        .font(.system(size: 17))
    }

    private var mapView: some View {
        Map(position: $camera) {
            UserAnnotation()

            // Unselected routes are faded; the selected one is drawn on top, bold
            ForEach(controller.routes) { option in
                if option.id != controller.selectedID {
                    MapPolyline(option.route.polyline)
                        .stroke(Theme.navy.opacity(0.25), lineWidth: 5)
                }
            }
            if let selected = controller.selectedRoute {
                MapPolyline(selected.route.polyline)
                    .stroke(Theme.navy, lineWidth: 7)
            }

            Marker(destination.name ?? "Destination", coordinate: destination.mapCoordinate)
                .tint(Theme.navy)
        }
        .mapControls { MapUserLocationButton() }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.fieldBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var content: some View {
        if !hasLocation {
            statusRow("Waiting for your location…")
        } else if controller.isLoading {
            statusRow("Finding walking routes…")
        } else if controller.routes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MessageBanner(error: controller.errorMessage ?? "No routes found.", info: nil)
                Button("Try again") { Task { await loadIfNeeded() } }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.navy)
            }
        } else {
            routeList
        }
    }

    private func statusRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(text).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var routeList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Community-rated routes")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.navy)
                Spacer()
                Text("Ratings out of 5")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }

            ForEach(controller.routes) { option in
                routeCard(option)
            }

            if let message = controller.errorMessage {
                MessageBanner(error: message, info: nil)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle").foregroundColor(Theme.textSecondary)
                Text(footnote)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private func routeCard(_ option: RouteOption) -> some View {
        let selected = option.id == controller.selectedID
        let low = option.isLowScore

        return Button {
            controller.select(option.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: selected ? "checkmark.circle" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(low ? Theme.danger : Theme.navy)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.title)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(Theme.navy)
                        Text(option.subtitle)
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer(minLength: 8)
                    Text("\(option.minutes) min")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.navy)
                }
                scoreRow(option)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(selected: selected, low: low))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(cardBorder(selected: selected, low: low), lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func scoreRow(_ option: RouteOption) -> some View {
        if let lighting = option.lighting, let crowd = option.crowd {
            HStack(spacing: 18) {
                Label(String(format: "%.1f lighting", lighting), systemImage: "lightbulb")
                Label(String(format: "%.1f crowd", crowd), systemImage: "person.2")
            }
            .font(.system(size: 16))
            .foregroundColor(Theme.navy)
        } else {
            Label("No community ratings yet", systemImage: "questionmark.circle")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private func cardBackground(selected: Bool, low: Bool) -> Color {
        if low { return Theme.danger.opacity(0.06) }
        return selected ? Theme.field : Color.white.opacity(0.6)
    }

    private func cardBorder(selected: Bool, low: Bool) -> Color {
        if low { return Theme.danger.opacity(0.35) }
        return selected ? Theme.navy : Theme.fieldBorder
    }

    private var footnote: String {
        var text = "Community ratings are not safety guarantees; conditions can change."
        if let reports = controller.selectedRoute?.reports, reports > 0 {
            text = "Based on \(reports) recent reports. " + text
        }
        if controller.hasDemoData { text += " Includes sample ratings for demo." }
        return text
    }

    // Pinned to the bottom of the screen
    private var startBar: some View {
        VStack(spacing: 8) {
            MessageBanner(error: walk.errorMessage, info: nil)
            PrimaryButton(title: startTitle,
                          isLoading: walk.isStarting,
                          isEnabled: controller.selectedRoute != nil && !contacts.contacts.isEmpty) {
                startWalk()
            }
            Text(shareText)
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.background)
    }

    private func startWalk() {
        guard let option = controller.selectedRoute,
              let uid = auth.currentUser?.uid else { return }
        Task {
            let started = await walk.start(route: option.route,
                                           destinationName: destination.name ?? "Destination",
                                           destination: destination.mapCoordinate,
                                           ownerUid: uid,
                                           ownerName: auth.displayName,
                                           location: location)
            if started { dismiss() }   // back to Home; the walk screen covers the app
        }
    }

    private var startTitle: String {
        guard let route = controller.selectedRoute else { return "Start walk" }
        return "Start \(route.minutes)-minute walk"
    }

    private var shareText: String {
        let names = contacts.contacts.compactMap { $0.name.split(separator: " ").first.map(String.init) }
        switch names.count {
        case 0: return "Add a trusted contact to share your walk."
        case 1: return "Shares with \(names[0]) during this walk only"
        default:
            let list = names.dropLast().joined(separator: ", ") + " & " + (names.last ?? "")
            return "Shares with \(list) during this walk only"
        }
    }

    #if DEBUG
    // Only in debug builds (Run from Xcode). Adds clearly flagged sample ratings.
    private var demoTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Demo tools")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            HStack(spacing: 12) {
                demoButton("Load demo ratings") { await controller.seedDemo() }
                demoButton("Clear demo ratings") { await controller.clearDemo() }
            }
            if controller.isSeeding { ProgressView() }
        }
        .padding(.top, 8)
    }

    private func demoButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.navy)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Theme.field)
                .clipShape(Capsule())
        }
        .disabled(controller.isSeeding || controller.routes.isEmpty)
    }
    #endif

    // MARK: - Helpers

    private func loadIfNeeded() async {
        guard let coordinate = location.location?.coordinate else { return }
        guard controller.routes.isEmpty, !controller.isLoading else { return }
        await controller.load(from: coordinate, to: destination)
    }

    // Zoom so every route is visible
    private func fitCamera() {
        let rect = controller.routes.reduce(MKMapRect.null) {
            $0.union($1.route.polyline.boundingMapRect)
        }
        guard !rect.isNull else { return }
        camera = .rect(rect.insetBy(dx: -rect.width * 0.25, dy: -rect.height * 0.25))
    }
}
*/
import SwiftUI
import MapKit
import FirebaseAuth

// "Choose a route": map with the options drawn on it + community-rated route cards
struct RoutesView: View {
    let destination: MKMapItem

    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var contacts: ContactController
    @EnvironmentObject private var auth: AuthController
    @EnvironmentObject private var walk: WalkController
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = RoutesController()

    @State private var camera: MapCameraPosition = .automatic
    @State private var showSheet = false
    @State private var detent: PresentationDetent = .medium

    private var hasLocation: Bool { location.location != nil }

    var body: some View {
        // The map fills the screen. The routes live in a sheet that slides up over it.
        mapView
            .overlay(alignment: .top) {
                breadcrumb
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
            }
            .navigationTitle("Choose a route")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { location.start() }
            // Open the sheet a moment after the screen appears (two presentations at once get ignored)
            .task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                showSheet = true
            }
            .onDisappear { showSheet = false }
            // Runs once the first GPS fix arrives
            .task(id: hasLocation) { await loadIfNeeded() }
            .onChange(of: controller.routes.count) { _, _ in fitCamera() }
            .sheet(isPresented: $showSheet) { sheetContent }
    }

    private var sheetContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
                #if DEBUG
                demoTools
                #endif
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) { startBar }
        .presentationDetents([.height(300), .medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationBackground(Theme.background)
        .interactiveDismissDisabled()
    }

    // MARK: - Pieces

    private var breadcrumb: some View {
        HStack(spacing: 8) {
            Text("Your location")
                .foregroundColor(Theme.textSecondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
            Text(destination.name ?? "Destination")
                .fontWeight(.semibold)
                .foregroundColor(Theme.navy)
                .lineLimit(1)
        }
        .font(.system(size: 17))
    }

    private var mapView: some View {
        Map(position: $camera) {
            UserAnnotation()

            // Unselected routes are faded; the selected one is drawn on top, bold
            ForEach(controller.routes) { option in
                if option.id != controller.selectedID {
                    MapPolyline(option.route.polyline)
                        .stroke(Theme.navy.opacity(0.25), lineWidth: 5)
                }
            }
            if let selected = controller.selectedRoute {
                MapPolyline(selected.route.polyline)
                    .stroke(Theme.navy, lineWidth: 7)
            }

            Marker(destination.name ?? "Destination", coordinate: destination.mapCoordinate)
                .tint(Theme.navy)
        }
        .mapControls { MapUserLocationButton() }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var content: some View {
        if !hasLocation {
            VStack(alignment: .leading, spacing: 12) {
                statusRow("Waiting for your location…")
                locationHelp
            }
        } else if controller.isLoading {
            statusRow("Finding walking routes…")
        } else if controller.routes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MessageBanner(error: controller.errorMessage ?? "No routes found.", info: nil)
                Button("Try again") { Task { await loadIfNeeded() } }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.navy)
            }
        } else {
            routeList
        }
    }

    // Explains why there is no location yet, with buttons that fix the usual causes
    private var locationHelp: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(location.statusText)
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)

            if location.status == .notDetermined {
                helpButton("Allow location") { location.start() }
            }
            if location.isDenied {
                helpButton("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            #if DEBUG
            helpButton("Use test location (Manipal)") {
                location.useTestLocation(latitude: 13.3525, longitude: 74.7928)
            }
            #endif
        }
    }

    private func helpButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.navy)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Theme.field)
                .clipShape(Capsule())
        }
    }

    private func statusRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(text).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var routeList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Community-rated routes")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.navy)
                Spacer()
                Text("Ratings out of 5")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }

            ForEach(controller.routes) { option in
                routeCard(option)
            }

            if let message = controller.errorMessage {
                MessageBanner(error: message, info: nil)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle").foregroundColor(Theme.textSecondary)
                Text(footnote)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private func routeCard(_ option: RouteOption) -> some View {
        let selected = option.id == controller.selectedID
        let low = option.isLowScore

        return Button {
            controller.select(option.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: selected ? "checkmark.circle" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(low ? Theme.danger : Theme.navy)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.title)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(Theme.navy)
                        Text(option.subtitle)
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer(minLength: 8)
                    Text("\(option.minutes) min")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.navy)
                }
                scoreRow(option)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(selected: selected, low: low))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(cardBorder(selected: selected, low: low), lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func scoreRow(_ option: RouteOption) -> some View {
        if let lighting = option.lighting, let crowd = option.crowd {
            HStack(spacing: 14) {
                Label(String(format: "%.1f light", lighting), systemImage: "lightbulb")
                Label(String(format: "%.1f crowd", crowd), systemImage: "person.2")
                if let safety = option.safety {
                    Label(String(format: "%.1f safe", safety), systemImage: "shield")
                }
            }
            .font(.system(size: 15))
            .foregroundColor(Theme.navy)
        } else {
            Label("No community ratings yet", systemImage: "questionmark.circle")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private func cardBackground(selected: Bool, low: Bool) -> Color {
        if low { return Theme.danger.opacity(0.06) }
        return selected ? Theme.field : Color.white.opacity(0.6)
    }

    private func cardBorder(selected: Bool, low: Bool) -> Color {
        if low { return Theme.danger.opacity(0.35) }
        return selected ? Theme.navy : Theme.fieldBorder
    }

    private var footnote: String {
        var text = "Community ratings are not safety guarantees; conditions can change."
        if let reports = controller.selectedRoute?.reports, reports > 0 {
            text = "Based on \(reports) recent reports. " + text
        }
        if controller.hasDemoData { text += " Includes sample ratings for demo." }
        return text
    }

    // Pinned to the bottom of the screen
    private var startBar: some View {
        VStack(spacing: 8) {
            MessageBanner(error: walk.errorMessage, info: nil)
            PrimaryButton(title: startTitle,
                          isLoading: walk.isStarting,
                          isEnabled: controller.selectedRoute != nil && !contacts.contacts.isEmpty) {
                startWalk()
            }
            Text(shareText)
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.background)
    }

    private func startWalk() {
        guard let option = controller.selectedRoute,
              let uid = auth.currentUser?.uid else { return }
        Task {
            let started = await walk.start(route: option.route,
                                           destinationName: destination.name ?? "Destination",
                                           destination: destination.mapCoordinate,
                                           ownerUid: uid,
                                           ownerName: auth.displayName,
                                           location: location)
            if started {
                showSheet = false
                try? await Task.sleep(nanoseconds: 400_000_000)
                dismiss()   // back to Home; the walk screen covers the app
            }
        }
    }

    private var startTitle: String {
        guard let route = controller.selectedRoute else { return "Start walk" }
        return "Start \(route.minutes)-minute walk"
    }

    private var shareText: String {
        let names = contacts.contacts.compactMap { $0.name.split(separator: " ").first.map(String.init) }
        switch names.count {
        case 0: return "Add a trusted contact to share your walk."
        case 1: return "Shares with \(names[0]) during this walk only"
        default:
            let list = names.dropLast().joined(separator: ", ") + " & " + (names.last ?? "")
            return "Shares with \(list) during this walk only"
        }
    }

    #if DEBUG
    // Only in debug builds (Run from Xcode). Adds clearly flagged sample ratings.
    private var demoTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Demo tools")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            HStack(spacing: 12) {
                demoButton("Load demo ratings") { await controller.seedDemo() }
                demoButton("Clear demo ratings") { await controller.clearDemo() }
            }
            if controller.isSeeding { ProgressView() }
        }
        .padding(.top, 8)
    }

    private func demoButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.navy)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Theme.field)
                .clipShape(Capsule())
        }
        .disabled(controller.isSeeding || controller.routes.isEmpty)
    }
    #endif

    // MARK: - Helpers

    private func loadIfNeeded() async {
        guard let coordinate = location.location?.coordinate else { return }
        guard controller.routes.isEmpty, !controller.isLoading else { return }
        await controller.load(from: coordinate, to: destination)
    }

    // Zoom so every route is visible
    private func fitCamera() {
        let rect = controller.routes.reduce(MKMapRect.null) {
            $0.union($1.route.polyline.boundingMapRect)
        }
        guard !rect.isNull else { return }
        // Extra room below the routes, because the sheet covers the lower half of the map
        let padded = MKMapRect(x: rect.minX - rect.width * 0.3,
                               y: rect.minY - rect.height * 0.3,
                               width: rect.width * 1.6,
                               height: rect.height * 2.4)
        camera = .rect(padded)
    }
}
