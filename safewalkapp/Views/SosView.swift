import SwiftUI
import CoreLocation

// Emergency SOS: message the circle with the live link, call emergency services, or cancel
struct SOSView: View {
    @EnvironmentObject private var walk: WalkController
    @EnvironmentObject private var contacts: ContactController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var share: ShareRequest?
    @State private var confirmCancel = false
    @State private var closeAfterShare = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Emergency SOS")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Theme.navy)
                    Spacer()
                    Button("Back to walk") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.navy)
                }
                .padding(.top, 16)

                activeCard

                Text("Alert your circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.navy)

                ForEach(contacts.contacts) { contact in
                    HStack(spacing: 14) {
                        Text(contact.initials)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.navy)
                            .frame(width: 48, height: 48)
                            .background(Theme.field)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Theme.navy)
                            Text(contact.maskedPhone)
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }

                Button {
                    share = ShareRequest(recipients: contacts.contacts.map(\.phone),
                                         text: walk.shareText(.sos))
                } label: {
                    Label("Message my circle with my location", systemImage: "message.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(Theme.navy)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                }

                locationCard

                Button {
                    if let url = URL(string: "tel://\(AppConfig.emergencyNumber)") { openURL(url) }
                } label: {
                    Label("Call \(AppConfig.emergencyNumber)", systemImage: "phone.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .background(Theme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle").foregroundColor(Theme.textSecondary)
                    Text("SafeWalk can't contact emergency services for you. Call \(AppConfig.emergencyNumber) for immediate help.")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }

                Button { confirmCancel = true } label: {
                    Text("Cancel SOS · false alarm")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(Theme.navy)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { walk.triggerSOS() }
        .sheet(item: $share) { request in
            MessageSheet(recipients: request.recipients, text: request.text) { _ in
                share = nil
                if closeAfterShare { dismiss() }
            }
        }
        .confirmationDialog("Cancel SOS?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel SOS, I'm okay") {
                walk.cancelSOS()
                dismiss()
            }
            Button("Cancel SOS and tell my circle") {
                walk.cancelSOS()
                closeAfterShare = true
                share = ShareRequest(recipients: contacts.contacts.map(\.phone),
                                     text: walk.shareText(.falseAlarm))
            }
            Button("Keep SOS on", role: .cancel) {}
        } message: {
            Text("Your walk keeps going until you end it.")
        }
    }

    private var activeCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "light.beacon.max.fill")
                .font(.system(size: 28))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(Theme.danger)
                .clipShape(Circle())
            Text("SOS is on")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.danger)
            Text("Your live link now shows an SOS. Message your circle so they open it.")
                .font(.system(size: 16))
                .foregroundColor(Theme.navy)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Theme.danger.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var locationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse").foregroundColor(Theme.navy)
            VStack(alignment: .leading, spacing: 2) {
                Text(walk.current.map {
                    String(format: "%.5f, %.5f", $0.coordinate.latitude, $0.coordinate.longitude)
                } ?? "Finding your location…")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.navy)
                Text("Shared live while your walk is active")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.fieldBorder, lineWidth: 1))
    }
}
