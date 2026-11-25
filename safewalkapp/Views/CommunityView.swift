import SwiftUI
import MapKit

// Community tab: a map divided into squares. Coloured squares have ratings; tap one to rate it.
struct CommunityView: View {
    @EnvironmentObject private var location: LocationService
    @StateObject private var controller = CommunityController()

    @State private var camera: MapCameraPosition = .automatic
    @State private var visibleCenter: CLLocationCoordinate2D?
    @State private var showRate = false

    // Used when the phone has no location yet (for example the simulator)
    private static let fallbackCenter = CLLocationCoordinate2D(latitude: 13.3525, longitude: 74.7928)

    private var hasLocation: Bool { location.location != nil }

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                UserAnnotation()
                ForEach(controller.drawCells, id: \.self) { id in
                    MapPolygon(coordinates: Grid.corners(of: id))
                        .foregroundStyle(fill(for: id))
                        .stroke(outline(for: id), lineWidth: id == controller.selectedCell ? 3 : 1.5)
                }
            }
            .mapControls { MapUserLocationButton() }
            // A tap that works together with the map's own drag and zoom gestures
            .simultaneousGesture(
                SpatialTapGesture().onEnded { tap in
                    if let coordinate = proxy.convert(tap.location, from: .local) {
                        controller.select(coordinate)
                    }
                }
            )
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleCenter = context.region.center
            }
        }
        .overlay(alignment: .top) { header }
        .safeAreaInset(edge: .bottom) { panel }
        .onAppear { location.start() }
        .task(id: hasLocation) {
            let center = location.location?.coordinate ?? Self.fallbackCenter
            camera = .region(MKCoordinateRegion(center: center,
                                                span: MKCoordinateSpan(latitudeDelta: 0.016,
                                                                       longitudeDelta: 0.016)))
            await controller.load(around: center)
        }
        .sheet(isPresented: $showRate) {
            RateSheet(controller: controller, isPresented: $showRate)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Community map")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.navy)
            Text(summaryLine)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
            HStack(spacing: 14) {
                legend(Theme.safe, "Safe")
                legend(Theme.caution, "Fair")
                legend(Theme.danger, "Poor")
                legend(Color.gray, "No ratings")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // Tells the user what the map is showing, even when nothing has been rated yet
    private var summaryLine: String {
        if controller.isLoading { return "Loading ratings…" }
        let rated = controller.scores.values.filter { $0.count > 0 }.count
        if rated == 0 { return "No ratings in this area yet. Tap a square to add the first one." }
        return "\(rated) of \(controller.cells.count) squares nearby have ratings."
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.5)).frame(width: 14, height: 14)
            Text(text).font(.system(size: 12)).foregroundColor(Theme.textSecondary)
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let id = controller.selectedCell {
                selectedInfo(id)
                PrimaryButton(title: "Rate this area", isLoading: false, isEnabled: true) {
                    showRate = true
                }
            } else {
                Text("Tap a square on the map to rate that street area.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
            }

            MessageBanner(error: controller.message, info: nil)

            HStack(spacing: 18) {
                Button {
                    if let here = location.location?.coordinate {
                        controller.select(here)
                    }
                } label: {
                    Label("Rate where I am", systemImage: "location.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.navy)
                }
                .disabled(location.location == nil)

                Button {
                    if let center = visibleCenter {
                        Task { await controller.load(around: center) }
                    }
                } label: {
                    Label("Load ratings for this area", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.navy)
                }
                if controller.isLoading { ProgressView().padding(.leading, 6) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
    }

    @ViewBuilder
    private func selectedInfo(_ id: String) -> some View {
        if let score = controller.scores[id], score.count > 0 {
            Text("\(score.count) rating\(score.count == 1 ? "" : "s") here · "
                 + String(format: "%.1f light · %.1f crowd", score.lighting, score.crowd)
                 + (score.safety.map { String(format: " · %.1f safe", $0) } ?? ""))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.navy)
        } else {
            Text("No ratings here yet. Be the first.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.navy)
        }
    }

    private func baseColor(for id: String) -> Color {
        switch controller.tint(for: id) {
        case .good: return Theme.safe
        case .fair: return Theme.caution
        case .poor: return Theme.danger
        case .unrated: return Color.gray
        }
    }

    private func fill(for id: String) -> Color {
        let isRated = controller.tint(for: id) != .unrated
        return baseColor(for: id).opacity(isRated ? 0.45 : 0.14)
    }

    private func outline(for id: String) -> Color {
        id == controller.selectedCell ? Theme.navy : baseColor(for: id).opacity(0.75)
    }
}

// MARK: - Rating sheet

private struct RateSheet: View {
    @ObservedObject var controller: CommunityController
    @Binding var isPresented: Bool

    @State private var lighting = 0
    @State private var crowd = 0
    @State private var safety = 0

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Rate this area")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Theme.navy)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.textSecondary)
                }
                .accessibilityLabel("Close")
            }
            .padding(.top, 24)

            Text("Think of the street as you walked it. Ratings are anonymous.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)

            scale("Lighting", low: "Very dark", high: "Well lit", value: $lighting)
            scale("Crowd", low: "Empty", high: "Busy", value: $crowd)
            scale("Safety", low: "Felt unsafe", high: "Felt safe", value: $safety)

            MessageBanner(error: controller.message, info: nil)

            PrimaryButton(title: "Submit rating",
                          isLoading: controller.isSaving,
                          isEnabled: lighting > 0 && crowd > 0 && safety > 0) {
                Task {
                    if await controller.submit(lighting: lighting, crowd: crowd, safety: safety) {
                        isPresented = false
                    }
                }
            }

            Button("Cancel") { isPresented = false }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.navy)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func scale(_ title: String, low: String, high: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.navy)
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { n in
                    Button { value.wrappedValue = n } label: {
                        Text("\(n)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(value.wrappedValue == n ? .white : Theme.navy)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(value.wrappedValue == n ? Theme.navy : Theme.field)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.system(size: 13))
            .foregroundColor(Theme.textSecondary)
        }
    }
}
