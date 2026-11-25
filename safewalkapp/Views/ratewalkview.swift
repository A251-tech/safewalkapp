import SwiftUI
import Combine
import MapKit

// CONTROLLER for the "Rate your walk" sheet: three scores for the whole route,
// plus up to two flagged spots that felt very dark or unsafe.
@MainActor
final class RateWalkController: ObservableObject {
    @Published var lighting = 0
    @Published var crowd = 0
    @Published var safety = 0
    @Published private(set) var flagged: [String] = []   // at most 2 cell ids
    @Published private(set) var isSaving = false
    @Published var message: String?

    let cells: [String]   // every grid cell the route passed through
    private let service = RatingService()
    static let maxFlags = 2

    init(route: WalkPath) {
        cells = Grid.cells(along: route)
    }

    var canSubmit: Bool { lighting > 0 && crowd > 0 && safety > 0 }

    /// Tap a square on the route to flag it; tap again to remove the flag
    func toggleFlag(at coordinate: CLLocationCoordinate2D) {
        let id = Grid.cellID(for: coordinate)
        guard cells.contains(id) else { return }
        if let index = flagged.firstIndex(of: id) {
            flagged.remove(at: index)
            message = nil
        } else if flagged.count < Self.maxFlags {
            flagged.append(id)
            message = nil
        } else {
            message = "You can flag up to \(Self.maxFlags) spots."
        }
    }

    func submit() async -> Bool {
        guard canSubmit else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.submitWalk(cells: cells, lighting: lighting, crowd: crowd,
                                         safety: safety, flagged: Set(flagged))
            return true
        } catch {
            message = "Could not save your rating. Check your connection and Firestore rules."
            return false
        }
    }
}

// Shown when the walker arrives. onFinish(true) = rating saved, onFinish(false) = skipped.
struct RateWalkView: View {
    let route: WalkPath
    let destinationName: String
    let onFinish: (Bool) -> Void

    @StateObject private var controller: RateWalkController
    @State private var camera: MapCameraPosition

    init(route: WalkPath, destinationName: String, onFinish: @escaping (Bool) -> Void) {
        self.route = route
        self.destinationName = destinationName
        self.onFinish = onFinish
        _controller = StateObject(wrappedValue: RateWalkController(route: route))
        let rect = route.polyline.boundingMapRect
        _camera = State(initialValue: .rect(rect.insetBy(dx: -rect.width * 0.2,
                                                         dy: -rect.height * 0.2)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("How was your walk?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Theme.navy)
                    .padding(.top, 24)

                Text("Your walk to \(destinationName). Your answers are anonymous and help the next person choose a route.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)

                RatingScale(title: "Lighting", low: "Very dark", high: "Well lit",
                            value: $controller.lighting)
                RatingScale(title: "Crowd", low: "Empty", high: "Busy",
                            value: $controller.crowd)
                RatingScale(title: "Safety", low: "Felt unsafe", high: "Felt safe",
                            value: $controller.safety)

                flagSection

                MessageBanner(error: controller.message, info: nil)

                PrimaryButton(title: "Submit rating",
                              isLoading: controller.isSaving,
                              isEnabled: controller.canSubmit) {
                    Task { if await controller.submit() { onFinish(true) } }
                }
                Button("Skip") { onFinish(false) }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.navy)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.large])
    }

    // The route's squares. Tap a square where it felt very dark or unsafe.
    private var flagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Any spot that felt very dark or unsafe?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.navy)
            Text("Optional. Tap up to 2 squares on your route. They are saved as very dark and unsafe.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)

            MapReader { proxy in
                Map(position: $camera) {
                    MapPolyline(route.polyline)
                        .stroke(Theme.navy, lineWidth: 5)
                    ForEach(controller.cells, id: \.self) { id in
                        let isFlagged = controller.flagged.contains(id)
                        MapPolygon(coordinates: Grid.corners(of: id))
                            .foregroundStyle(isFlagged ? Theme.danger.opacity(0.45) : Theme.navy.opacity(0.06))
                            .stroke(isFlagged ? Theme.danger : Theme.navy.opacity(0.3),
                                    lineWidth: isFlagged ? 3 : 1)
                    }
                }
                .simultaneousGesture(
                    SpatialTapGesture().onEnded { tap in
                        if let coordinate = proxy.convert(tap.location, from: .local) {
                            controller.toggleFlag(at: coordinate)
                        }
                    }
                )
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.fieldBorder, lineWidth: 1))

            Text(controller.flagged.isEmpty
                 ? "No spots flagged."
                 : "\(controller.flagged.count) spot\(controller.flagged.count == 1 ? "" : "s") flagged.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// Five numbered buttons with a label at each end
struct RatingScale: View {
    let title: String
    let low: String
    let high: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.navy)
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { n in
                    Button { value = n } label: {
                        Text("\(n)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(value == n ? .white : Theme.navy)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(value == n ? Theme.navy : Theme.field)
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
