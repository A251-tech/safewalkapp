/*import SwiftUI

// Identifiable wrapper so one .sheet can handle both "add" and "edit"
struct ContactSheet: Identifiable {
    let id = UUID()
    let contact: TrustedContact?   // nil = adding a new contact
}

struct CircleView: View {
    @EnvironmentObject private var contacts: ContactController
    @State private var sheet: ContactSheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Trusted circle")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Theme.navy)
                    .padding(.top, 16)

                Text("Your people, one tap away. Choose who can follow your active walks and receive alerts.")
                    .font(.system(size: 17))
                    .foregroundColor(Theme.textSecondary)

                if contacts.hasLoaded && contacts.contacts.isEmpty {
                    emptyState
                }

                ForEach(contacts.contacts) { contact in
                    Button { sheet = ContactSheet(contact: contact) } label: {
                        ContactRow(contact: contact)
                    }
                    .buttonStyle(.plain)
                }

                if contacts.canAddMore {
                    Button { sheet = ContactSheet(contact: nil) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.plus")
                            Text("Add trusted contact")
                        }
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(Theme.navy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }

                alertSettingsSection

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock").foregroundColor(Theme.navy)
                    Text("Contacts can see your location only during an active walk. SOS alerts always go to your trusted circle.")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $sheet) { item in
            AddContactView(contact: item.contact)
        }
    }

    private var emptyState: some View {
        Text("No one here yet. Add a friend, roommate or family member who should be alerted during a walk.")
            .font(.system(size: 16))
            .foregroundColor(Theme.textSecondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.field)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var alertSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Automatic walk alerts")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.navy)
                .padding(.top, 8)

            VStack(spacing: 18) {
                toggleRow(icon: "timer", title: "Missed check-in",
                          subtitle: "After the check-in timer expires",
                          isOn: binding(\.missedCheckIn))
                toggleRow(icon: "point.topleft.down.curvedto.point.bottomright.up",
                          title: "Route deviation",
                          subtitle: "If you move away from your route",
                          isOn: binding(\.routeDeviation))
                toggleRow(icon: "mappin.and.ellipse", title: "Arrival notification",
                          subtitle: "When you finish at your destination",
                          isOn: binding(\.arrival))
            }
            .padding(18)
            .background(Color.white.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.fieldBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // Writes the toggle change to the controller, then saves to Firestore
    private func binding(_ keyPath: WritableKeyPath<AlertSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { contacts.settings[keyPath: keyPath] },
            set: { newValue in
                contacts.settings[keyPath: keyPath] = newValue
                contacts.saveSettings()
            }
        )
    }

    private func toggleRow(icon: String, title: String, subtitle: String,
                           isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Theme.navy)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.navy)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.navy)
        }
    }
}

// One contact card in the list
struct ContactRow: View {
    let contact: TrustedContact

    var body: some View {
        HStack(spacing: 16) {
            Text(contact.initials)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.navy)
                .frame(width: 56, height: 56)
                .background(Theme.field)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.navy)
                Text("\(contact.relationship) · \(contact.maskedPhone)")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.navy)
                HStack(spacing: 6) {
                    Image(systemName: contact.status == .accepted ? "checkmark" : "clock")
                    Text(contact.status == .accepted
                         ? "Accepted · Receives walk alerts"
                         : "Invite pending")
                }
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundColor(Theme.navy)
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.fieldBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}*/
//code taht has the ios messge sending invite part
import SwiftUI

// Identifiable wrapper so one .sheet can handle both "add" and "edit"
struct ContactSheet: Identifiable {
    let id = UUID()
    let contact: TrustedContact?   // nil = adding a new contact
}

struct CircleView: View {
    @EnvironmentObject private var contacts: ContactController
    @State private var sheet: ContactSheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Trusted circle")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Theme.navy)
                    .padding(.top, 16)

                Text("Your people, one tap away. Choose who can follow your active walks and receive alerts.")
                    .font(.system(size: 17))
                    .foregroundColor(Theme.textSecondary)

                if contacts.hasLoaded && contacts.contacts.isEmpty {
                    emptyState
                }

                ForEach(contacts.contacts) { contact in
                    Button { sheet = ContactSheet(contact: contact) } label: {
                        ContactRow(contact: contact)
                    }
                    .buttonStyle(.plain)
                }

                if contacts.canAddMore {
                    Button { sheet = ContactSheet(contact: nil) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.plus")
                            Text("Add trusted contact")
                        }
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(Theme.navy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }

                alertSettingsSection

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock").foregroundColor(Theme.navy)
                    Text("Contacts can see your location only during an active walk. SOS alerts always go to your trusted circle.")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $sheet) { item in
            AddContactView(contact: item.contact)
        }
    }

    private var emptyState: some View {
        Text("No one here yet. Add a friend, roommate or family member who should be alerted during a walk.")
            .font(.system(size: 16))
            .foregroundColor(Theme.textSecondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.field)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var alertSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Automatic walk alerts")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.navy)
                .padding(.top, 8)

            VStack(spacing: 18) {
                toggleRow(icon: "timer", title: "Missed check-in",
                          subtitle: "After the check-in timer expires",
                          isOn: binding(\.missedCheckIn))
                toggleRow(icon: "point.topleft.down.curvedto.point.bottomright.up",
                          title: "Route deviation",
                          subtitle: "If you move away from your route",
                          isOn: binding(\.routeDeviation))
                toggleRow(icon: "mappin.and.ellipse", title: "Arrival notification",
                          subtitle: "When you finish at your destination",
                          isOn: binding(\.arrival))
            }
            .padding(18)
            .background(Color.white.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.fieldBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // Writes the toggle change to the controller, then saves to Firestore
    private func binding(_ keyPath: WritableKeyPath<AlertSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { contacts.settings[keyPath: keyPath] },
            set: { newValue in
                contacts.settings[keyPath: keyPath] = newValue
                contacts.saveSettings()
            }
        )
    }

    private func toggleRow(icon: String, title: String, subtitle: String,
                           isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Theme.navy)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.navy)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.navy)
        }
    }
}

// One contact card in the list
struct ContactRow: View {
    let contact: TrustedContact

    private var statusText: String {
        if contact.status == .accepted { return "Accepted · Receives walk alerts" }
        return contact.invitedAt == nil ? "Invite not sent yet" : "Invite sent · Waiting for them to join"
    }

    private var statusIcon: String {
        if contact.status == .accepted { return "checkmark" }
        return contact.invitedAt == nil ? "paperplane" : "clock"
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(contact.initials)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.navy)
                .frame(width: 56, height: 56)
                .background(Theme.field)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.navy)
                Text("\(contact.relationship) · \(contact.maskedPhone)")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.navy)
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                    Text(statusText)
                }
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundColor(Theme.navy)
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.fieldBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
