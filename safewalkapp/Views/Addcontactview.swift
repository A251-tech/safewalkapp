import SwiftUI

// Sheet used both to add a contact and to edit/remove an existing one
struct AddContactView: View {
    @EnvironmentObject private var contacts: ContactController
    @EnvironmentObject private var auth: AuthController
    @Environment(\.dismiss) private var dismiss

    let contact: TrustedContact?   // nil = add mode

    @State private var name: String
    @State private var phone: String
    @State private var relationship: String
    @State private var confirmDelete = false
    @State private var invite: InviteRequest?

    private let relationships = ["Roommate", "Friend", "Family", "Partner", "Other"]

    init(contact: TrustedContact?) {
        self.contact = contact
        _name = State(initialValue: contact?.name ?? "")
        _phone = State(initialValue: contact?.phone ?? "")
        _relationship = State(initialValue: contact?.relationship ?? "Friend")
    }

    private var isEditing: Bool { contact != nil }
    private var canSubmit: Bool { !name.isEmpty && !phone.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(isEditing ? "Edit contact" : "Add trusted contact")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Theme.navy)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.top, 24)

                Text("They'll be able to follow your walks and get your alerts.")
                    .font(.system(size: 17))
                    .foregroundColor(Theme.textSecondary)

                LabeledField(title: "Full name", placeholder: "Their full name",
                             text: $name, contentType: .name)

                LabeledField(title: "Phone number", placeholder: "+1 555 010 0142",
                             text: $phone,
                             hint: "Include the country code if they're outside your country.",
                             keyboard: .phonePad,
                             contentType: .telephoneNumber)

                relationshipPicker

                MessageBanner(error: contacts.errorMessage, info: nil)

                PrimaryButton(title: isEditing ? "Save changes" : "Add to circle",
                              isLoading: contacts.isLoading,
                              isEnabled: canSubmit) {
                    Task {
                        guard let id = await contacts.save(existing: contact, name: name,
                                                           relationship: relationship, phone: phone)
                        else { return }

                        if contact == nil {
                            // New contact: create its invite code, then offer the invite text.
                            // This sheet closes when the invite sheet closes.
                            let code = await contacts.inviteCode(forContactID: id, name: name,
                                                                 existing: nil,
                                                                 ownerName: auth.displayName)
                            invite = makeInvite(contactID: id,
                                                name: name,
                                                phone: ContactController.normalizePhone(phone),
                                                code: code)
                        } else {
                            dismiss()
                        }
                    }
                }

                if let contact, contact.status == .pending {
                    Button {
                        Task {
                            let code = await contacts.inviteCode(forContactID: contact.id,
                                                                 name: contact.name,
                                                                 existing: contact.inviteCode,
                                                                 ownerName: auth.displayName)
                            invite = makeInvite(contactID: contact.id, name: contact.name,
                                                phone: contact.phone, code: code)
                        }
                    } label: {
                        Label(contact.invitedAt == nil ? "Send invite" : "Send invite again",
                              systemImage: "message")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Theme.navy)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Theme.field)
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                    }
                }

                if isEditing {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Text("Remove from circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Theme.danger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { contacts.clearMessages() }
        .sheet(item: $invite, onDismiss: {
            // After adding a new contact, close the form once the invite step is over
            if contact == nil { dismiss() }
        }) { request in
            InviteSheet(phone: request.phone, messageText: request.text) { sent in
                if sent { Task { await contacts.markInvited(id: request.contactID) } }
                invite = nil
            }
        }
        .confirmationDialog("Remove \(contact?.name ?? "this contact")?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let contact {
                    Task { if await contacts.delete(contact) { dismiss() } }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will no longer receive your walk alerts.")
        }
    }

    private func makeInvite(contactID: String, name: String, phone: String, code: String?) -> InviteRequest {
        InviteRequest(contactID: contactID,
                      phone: phone,
                      text: InviteMessage.text(senderName: auth.displayName, contactName: name, code: code))
    }

    private var relationshipPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Relationship")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.navy)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(relationships, id: \.self) { option in
                        Button { relationship = option } label: {
                            Text(option)
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 18)
                                .frame(height: 44)
                                .foregroundColor(relationship == option ? .white : Theme.navy)
                                .background(relationship == option ? Theme.navy : Theme.field)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
}
