/*import SwiftUI
import MapKit

// "Walk to Maple Hall": live map, time left, next turn, check-in, End walk and SOS
struct ActiveWalkView: View {
    @EnvironmentObject private var walk: WalkController
    @EnvironmentObject private var contacts: ContactController

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showEndConfirm = false
    @State private var showSOS = false
    @State private var share: ShareRequest?
    @State private var offeredShare = false

    private let distance = MKDistanceFormatter()

    var body: some View {
        Group {
            if let session = walk.session {
                content(session)
            } else {
                Color.clear   // shown for a moment while the screen closes
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }

    // MARK: - Layout

    private func content(_ session: WalkSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(session)

                if walk.status == .arrived {
                    arrivedCard(session)
                } else {
                    instructionCard(session)
                }

                mapView(session)
                statsRow

                if walk.status == .missedCheckIn { missedBanner }
                if walk.isOffRoute, walk.status == .active {
                    MessageBanner(error: "You seem to be away from your route.", info: nil)
                }

                if walk.status != .arrived {
                    circleCard
                    Text("Your circle gets your live link. Location sharing stops when you end this walk.")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                    actionButtons
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $walk.showCheckIn) {
            CheckInView(onSOS: openSOSFromCheckIn)
                .environmentObject(walk)
                .environmentObject(contacts)
        }
        .sheet(item: $share) { request in
            MessageSheet(recipients: request.recipients, text: request.text) { _ in
                share = nil
            }
        }
        .fullScreenCover(isPresented: $showSOS) {
            SOSView()
                .environmentObject(walk)
                .environmentObject(contacts)
        }
        .confirmationDialog("End this walk?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End walk", role: .destructive) { walk.end() }
            Button("Keep walking", role: .cancel) {}
        } message: {
            Text("Your circle will stop seeing your location.")
        }
        .task {
            // Offer to text the live link to the circle as soon as the walk starts
            guard !offeredShare else { return }
            offeredShare = true
            try? await Task.sleep(nanoseconds: 800_000_000)
            openShare(.started)
        }
    }

    private func header(_ session: WalkSession) -> some View {
        HStack {
            Text("Walk to \(session.destinationName)")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Theme.navy)
                .lineLimit(2)
            Spacer()
            Menu {
                Button("Send live link to my circle") { openShare(.started) }
                Button("End walk", role: .destructive) { showEndConfirm = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.navy)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Walk options")
        }
        .padding(.top, 8)
    }

    private func instructionCard(_ session: WalkSession) -> some View {
        let step = walk.nextStep
        return HStack(spacing: 14) {
            Image(systemName: "arrow.turn.up.right")
                .font(.system(size: 24))
                .foregroundColor(Theme.navy)
                .frame(width: 56, height: 56)
                .background(Theme.field)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(step.map { "In \(distance.string(fromDistance: $0.meters))" } ?? "Head to \(session.destinationName)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.navy)
                Text(step?.text ?? "Follow the route on the map")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private func mapView(_ session: WalkSession) -> some View {
        Map(position: $camera) {
            UserAnnotation()
            MapPolyline(session.route.polyline)
                .stroke(Theme.navy, lineWidth: 7)
            Marker(session.destinationName, coordinate: session.destination)
                .tint(Theme.navy)
        }
        .mapControls { MapUserLocationButton() }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.fieldBorder, lineWidth: 1))
    }

    private var statsRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(walk.status == .arrived ? "Arrived" : "\(walk.minutesLeft) min")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(Theme.navy)
                if walk.status != .arrived {
                    Text("\(distance.string(fromDistance: walk.remainingMeters)) left · Arrive \(walk.arrivalTime.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
            statusPill
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        switch walk.status {
        case .sos:
            pill("SOS active", icon: "exclamationmark.triangle.fill", color: Theme.danger)
        case .missedCheckIn:
            pill("Check-in missed", icon: "clock.badge.exclamationmark", color: Theme.danger)
        case .arrived, .ended:
            pill("Sharing stopped", icon: "checkmark.circle", color: Theme.navy)
        case .active:
            pill("Sharing live", icon: "dot.radiowaves.left.and.right", color: Theme.navy)
        }
    }

    private func pill(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var circleCard: some View {
        Button { walk.showCheckIn = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    HStack(spacing: -8) {
                        ForEach(contacts.contacts.prefix(3)) { contact in
                            Text(contact.initials)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.navy)
                                .frame(width: 40, height: 40)
                                .background(Theme.field)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contacts.namesLine)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.navy)
                        Text("Your trusted circle")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    Image(systemName: "timer").foregroundColor(Theme.navy)
                    Text(walk.status == .missedCheckIn
                         ? "Check-in missed"
                         : "Next check-in in \(Fmt.clock(walk.nextCheckInAt.timeIntervalSince(walk.now)))")
                        .font(.system(size: 17))
                        .foregroundColor(Theme.navy)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Theme.navy)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.field)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.fieldBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var missedBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            MessageBanner(error: "You missed a check-in. Let your circle know you're okay, or alert them.", info: nil)
            HStack(spacing: 12) {
                Button("I'm safe") { walk.checkIn() }
                    .buttonStyle(PillStyle(fill: Theme.navy, text: .white))
                Button("Alert my circle") { openShare(.missedCheckIn) }
                    .buttonStyle(PillStyle(fill: Theme.danger, text: .white))
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { showEndConfirm = true } label: {
                Text("End walk")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.navy)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            Button { showSOS = true } label: {
                Label(walk.status == .sos ? "SOS active" : "SOS", systemImage: "light.beacon.max")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(Theme.danger)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }
        }
    }

    private func arrivedCard(_ session: WalkSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("You've arrived", systemImage: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.navy)
            Text("You're at \(session.destinationName). Location sharing has stopped.")
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)
            PrimaryButton(title: "Tell my circle I'm safe") { openShare(.arrived) }
            Button("Done") { walk.close() }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.navy)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .padding(18)
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Helpers

    private func openShare(_ kind: ShareKind) {
        let phones = contacts.contacts.map(\.phone)
        guard !phones.isEmpty else { return }
        share = ShareRequest(recipients: phones, text: walk.shareText(kind))
    }

    private func openSOSFromCheckIn() {
        walk.showCheckIn = false
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)   // let the sheet close first
            showSOS = true
        }
    }
}

// Rounded filled button used in banners
struct PillStyle: ButtonStyle {
    let fill: Color
    let text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(text)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(fill.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}
*/
import SwiftUI
import MapKit

// "Walk to Maple Hall": live map, time left, next turn, check-in, End walk and SOS
struct ActiveWalkView: View {
    @EnvironmentObject private var walk: WalkController
    @EnvironmentObject private var contacts: ContactController

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showEndConfirm = false
    @State private var showSOS = false
    @State private var share: ShareRequest?
    @State private var offeredShare = false
    @State private var showRate = false
    @State private var offeredRating = false
    @State private var didRate = false

    private let distance = MKDistanceFormatter()

    var body: some View {
        Group {
            if let session = walk.session {
                content(session)
            } else {
                Color.clear   // shown for a moment while the screen closes
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }

    // MARK: - Layout

    private func content(_ session: WalkSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(session)

                if isFinished {
                    arrivedCard(session)
                } else {
                    instructionCard(session)
                }

                mapView(session)
                statsRow

                if walk.status == .missedCheckIn { missedBanner }
                if walk.isOffRoute, walk.status == .active {
                    MessageBanner(error: "You seem to be away from your route.", info: nil)
                }

                if !isFinished {
                    circleCard
                    Text("Your circle gets your live link. Location sharing stops when you end this walk.")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                    actionButtons
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $walk.showCheckIn) {
            CheckInView(onSOS: openSOSFromCheckIn)
                .environmentObject(walk)
                .environmentObject(contacts)
        }
        .sheet(isPresented: $showRate) {
            RateWalkView(route: session.route, destinationName: session.destinationName) { rated in
                if rated { didRate = true }
                showRate = false
            }
        }
        // When the walk ends at the destination, ask how it went (once)
        .onChange(of: walk.status) { _, newStatus in
            guard newStatus == .arrived || newStatus == .ended, !offeredRating else { return }
            offeredRating = true
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                showRate = true
            }
        }
        .sheet(item: $share) { request in
            MessageSheet(recipients: request.recipients, text: request.text) { _ in
                share = nil
            }
        }
        .fullScreenCover(isPresented: $showSOS) {
            SOSView()
                .environmentObject(walk)
                .environmentObject(contacts)
        }
        .confirmationDialog("End this walk?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End walk", role: .destructive) { walk.end() }
            Button("Keep walking", role: .cancel) {}
        } message: {
            Text("Your circle will stop seeing your location.")
        }
        .task {
            // Offer to text the live link to the circle as soon as the walk starts
            guard !offeredShare else { return }
            offeredShare = true
            try? await Task.sleep(nanoseconds: 800_000_000)
            openShare(.started)
        }
    }

    private func header(_ session: WalkSession) -> some View {
        HStack {
            Text("Walk to \(session.destinationName)")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Theme.navy)
                .lineLimit(2)
            Spacer()
            Menu {
                Button("Send live link to my circle") { openShare(.started) }
                Button("End walk", role: .destructive) { showEndConfirm = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.navy)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Walk options")
        }
        .padding(.top, 8)
    }

    private func instructionCard(_ session: WalkSession) -> some View {
        let step = walk.nextStep
        return HStack(spacing: 14) {
            Image(systemName: "arrow.turn.up.right")
                .font(.system(size: 24))
                .foregroundColor(Theme.navy)
                .frame(width: 56, height: 56)
                .background(Theme.field)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(step.map { "In \(distance.string(fromDistance: $0.meters))" } ?? "Head to \(session.destinationName)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.navy)
                Text(step?.text ?? "Follow the route on the map")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private func mapView(_ session: WalkSession) -> some View {
        Map(position: $camera) {
            UserAnnotation()
            MapPolyline(session.route.polyline)
                .stroke(Theme.navy, lineWidth: 7)
            Marker(session.destinationName, coordinate: session.destination)
                .tint(Theme.navy)
        }
        .mapControls { MapUserLocationButton() }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.fieldBorder, lineWidth: 1))
    }

    private var statsRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isFinished ? (walk.status == .arrived ? "Arrived" : "Walk ended")
                                : "\(walk.minutesLeft) min")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(Theme.navy)
                if !isFinished {
                    Text("\(distance.string(fromDistance: walk.remainingMeters)) left · Arrive \(walk.arrivalTime.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
            statusPill
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        switch walk.status {
        case .sos:
            pill("SOS active", icon: "exclamationmark.triangle.fill", color: Theme.danger)
        case .missedCheckIn:
            pill("Check-in missed", icon: "clock.badge.exclamationmark", color: Theme.danger)
        case .arrived, .ended:
            pill("Sharing stopped", icon: "checkmark.circle", color: Theme.navy)
        case .active:
            pill("Sharing live", icon: "dot.radiowaves.left.and.right", color: Theme.navy)
        }
    }

    private func pill(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var circleCard: some View {
        Button { walk.showCheckIn = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    HStack(spacing: -8) {
                        ForEach(contacts.contacts.prefix(3)) { contact in
                            Text(contact.initials)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.navy)
                                .frame(width: 40, height: 40)
                                .background(Theme.field)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contacts.namesLine)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.navy)
                        Text("Your trusted circle")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    Image(systemName: "timer").foregroundColor(Theme.navy)
                    Text(walk.status == .missedCheckIn
                         ? "Check-in missed"
                         : "Next check-in in \(Fmt.clock(walk.nextCheckInAt.timeIntervalSince(walk.now)))")
                        .font(.system(size: 17))
                        .foregroundColor(Theme.navy)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Theme.navy)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.field)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.fieldBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var missedBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            MessageBanner(error: "You missed a check-in. Let your circle know you're okay, or alert them.", info: nil)
            HStack(spacing: 12) {
                Button("I'm safe") { walk.checkIn() }
                    .buttonStyle(PillStyle(fill: Theme.navy, text: .white))
                Button("Alert my circle") { openShare(.missedCheckIn) }
                    .buttonStyle(PillStyle(fill: Theme.danger, text: .white))
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { showEndConfirm = true } label: {
                Text("End walk")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.navy)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            Button { showSOS = true } label: {
                Label(walk.status == .sos ? "SOS active" : "SOS", systemImage: "light.beacon.max")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(Theme.danger)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }
        }
    }

    private func arrivedCard(_ session: WalkSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(walk.status == .arrived ? "You've arrived" : "Walk ended",
                  systemImage: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.navy)
            Text(walk.status == .arrived
                 ? "You're at \(session.destinationName). Location sharing has stopped."
                 : "Location sharing has stopped. How was your walk to \(session.destinationName)?")
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)
            PrimaryButton(title: "Tell my circle I'm safe") { openShare(.arrived) }
            Button {
                showRate = true
            } label: {
                Label(didRate ? "Thanks for rating" : "Rate this walk",
                      systemImage: didRate ? "checkmark.circle" : "star.bubble")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.navy)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .disabled(didRate)
            Button("Done") { walk.close() }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.navy)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .padding(18)
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Helpers

    // The walk is over (arrived at the destination, or ended by the user)
    private var isFinished: Bool { walk.status == .arrived || walk.status == .ended }

    private func openShare(_ kind: ShareKind) {
        let phones = contacts.contacts.map(\.phone)
        guard !phones.isEmpty else { return }
        share = ShareRequest(recipients: phones, text: walk.shareText(kind))
    }

    private func openSOSFromCheckIn() {
        walk.showCheckIn = false
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)   // let the sheet close first
            showSOS = true
        }
    }
}

// Rounded filled button used in banners
struct PillStyle: ButtonStyle {
    let fill: Color
    let text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(text)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(fill.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}
