import SwiftUI
import MapKit

// A contact follows someone's walk live (inside the app)
struct FollowWalkView: View {
    let code: String   // the invite code of the circle being followed

    @EnvironmentObject private var joined: JoinedCirclesController
    @Environment(\.dismiss) private var dismiss
    @StateObject private var watcher = WalkWatcher()
    @State private var camera: MapCameraPosition = .automatic

    private var circle: Invite? { joined.circles.first { $0.id == code } }
    private var walkId: String? { circle?.activeWalkId }
    private var ownerName: String { circle?.ownerName ?? "Your contact" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(ownerName)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Theme.navy)
                        .lineLimit(1)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.top, 24)

                if walkId == nil {
                    idleCard
                } else if let walk = watcher.walk {
                    liveContent(walk)
                } else if watcher.loaded {
                    idleCard
                } else {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Connecting to the live walk…").foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .task(id: walkId) {
            if let walkId { watcher.start(walkId: walkId) } else { watcher.stop() }
        }
        .onChange(of: watcher.walk?.lastUpdated) { _, _ in
            if let c = watcher.walk?.coordinate {
                camera = .region(MKCoordinateRegion(center: c, latitudinalMeters: 600, longitudinalMeters: 600))
            }
        }
        .onDisappear { watcher.stop() }
    }

    private var idleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Not on a walk right now", systemImage: "figure.walk")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.navy)
            Text("When \(ownerName) starts a walk, it appears here live.")
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func liveContent(_ walk: LiveWalk) -> some View {
        let urgent = walk.status == .sos || walk.status == .missedCheckIn

        Label(statusText(walk.status), systemImage: urgent ? "exclamationmark.triangle.fill" : "dot.radiowaves.left.and.right")
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(urgent ? Theme.danger : Theme.navy)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background((urgent ? Theme.danger : Theme.navy).opacity(0.12))
            .clipShape(Capsule())

        Text("Walking to \(walk.destinationName)")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(Theme.navy)

        if let c = walk.coordinate {
            Map(position: $camera) {
                Marker(ownerName, coordinate: c).tint(urgent ? Theme.danger : Theme.navy)
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.fieldBorder, lineWidth: 1))

            if let url = URL(string: String(format: "https://maps.apple.com/?ll=%.5f,%.5f", c.latitude, c.longitude)) {
                Link(destination: url) {
                    Label("Open in Maps", systemImage: "map")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.navy)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                }
            }
        } else {
            Text("Waiting for their location…")
                .foregroundColor(Theme.textSecondary)
        }

        if let updated = walk.lastUpdated, walk.status != .ended, walk.status != .arrived {
            HStack(spacing: 6) {
                Text("Last update")
                Text(updated, style: .relative)
                Text("ago")
            }
            .font(.system(size: 14))
            .foregroundColor(Theme.textSecondary)
        }
    }

    private func statusText(_ status: WalkStatus) -> String {
        switch status {
        case .active:        return "Walking · sharing live"
        case .missedCheckIn: return "Missed a check-in"
        case .sos:           return "SOS! Needs help"
        case .arrived:       return "Arrived safely"
        case .ended:         return "Walk ended"
        }
    }
}
