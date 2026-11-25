import Foundation
import Combine
import FirebaseFirestore

// CONTROLLER: contact list, validation, alert settings.
@MainActor
final class ContactController: ObservableObject {
    @Published private(set) var contacts: [TrustedContact] = []
    @Published var settings = AlertSettings()
    @Published private(set) var hasLoaded = false   // false until the first Firestore response
    @Published var isLoading = false
    @Published var errorMessage: String?

    static let maxContacts = 5

    private let service = ContactService()
    private let inviteService = InviteService()
    private var contactsListener: ListenerRegistration?
    private var settingsListener: ListenerRegistration?
    private var invitesListener: ListenerRegistration?
    private var uid: String?
    private var invites: [Invite] = []
    private var markedAccepted = Set<String>()

    // MARK: - Lifecycle

    func start(uid: String) {
        guard self.uid != uid else { return }
        stop()
        self.uid = uid

        contactsListener = service.listenContacts(uid: uid) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let list): self.contacts = list
                case .failure: self.errorMessage = "Could not load your trusted circle."
                }
                self.hasLoaded = true
                self.reconcile()
            }
        }
        settingsListener = service.listenSettings(uid: uid) { [weak self] value in
            Task { @MainActor in self?.settings = value }
        }
        // When someone types an invite code, the invite changes and the contact flips to "Accepted"
        invitesListener = inviteService.listenOwned(uid: uid) { [weak self] list in
            Task { @MainActor in
                self?.invites = list
                self?.reconcile()
            }
        }
    }

    /// Contacts whose invite was accepted get status "accepted" (saved to Firestore once)
    private func reconcile() {
        guard let uid else { return }
        for contact in contacts where contact.status == .pending {
            guard let code = contact.inviteCode,
                  let invite = invites.first(where: { $0.id == code }),
                  invite.isAccepted,
                  !markedAccepted.contains(contact.id) else { continue }
            markedAccepted.insert(contact.id)
            let id = contact.id
            Task { try? await service.markAccepted(uid: uid, id: id) }
        }
    }

    func stop() {
        contactsListener?.remove()
        settingsListener?.remove()
        invitesListener?.remove()
        contactsListener = nil
        settingsListener = nil
        invitesListener = nil
        uid = nil
        invites = []
        markedAccepted = []
        contacts = []
        hasLoaded = false
    }

    // MARK: - Actions

    var canAddMore: Bool { contacts.count < Self.maxContacts }

    /// Adds a new contact (existing == nil) or updates one.
    /// Returns the contact's id on success, or nil if something failed.
    func save(existing: TrustedContact?, name: String, relationship: String, phone: String) async -> String? {
        errorMessage = nil
        guard let uid else { return nil }

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = Self.normalizePhone(phone)

        guard !cleanName.isEmpty else {
            errorMessage = "Please enter the contact's name."
            return nil
        }
        guard Self.isValidPhone(cleanPhone) else {
            errorMessage = "Please enter a valid phone number."
            return nil
        }
        let isDuplicate = contacts.contains { $0.phone == cleanPhone && $0.id != existing?.id }
        guard !isDuplicate else {
            errorMessage = "This number is already in your trusted circle."
            return nil
        }
        if existing == nil && !canAddMore {
            errorMessage = "You can have up to \(Self.maxContacts) trusted contacts."
            return nil
        }

        isLoading = true
        defer { isLoading = false }
        do {
            if let existing {
                try await service.updateContact(uid: uid, id: existing.id, name: cleanName,
                                                relationship: relationship, phone: cleanPhone)
                return existing.id
            } else {
                return try await service.addContact(uid: uid, name: cleanName,
                                                    relationship: relationship, phone: cleanPhone)
            }
        } catch {
            errorMessage = "Could not save the contact. Please try again."
            return nil
        }
    }

    /// Call after the invite text was really sent
    func markInvited(id: String) async {
        guard let uid else { return }
        do { try await service.markInvited(uid: uid, id: id) }
        catch { errorMessage = "Could not update the invite status." }
    }

    /// The invite code for a contact. Creates the invite the first time.
    func inviteCode(forContactID id: String, name: String,
                    existing: String?, ownerName: String) async -> String? {
        if let existing { return existing }
        guard let uid else { return nil }
        do {
            let code = try await inviteService.createInvite(
                ownerUid: uid,
                ownerName: ownerName.isEmpty ? "Someone" : ownerName,
                contactId: id,
                contactName: name)
            try await service.setInviteCode(uid: uid, id: id, code: code)
            return code
        } catch {
            errorMessage = "Could not create the invite code. Check your Firestore rules."
            return nil
        }
    }

    func delete(_ contact: TrustedContact) async -> Bool {
        guard let uid else { return false }
        isLoading = true
        defer { isLoading = false }
        do {
            if let code = contact.inviteCode {
                try? await inviteService.deleteInvite(code: code)   // the code stops working
            }
            try await service.deleteContact(uid: uid, id: contact.id)
            return true
        } catch {
            errorMessage = "Could not remove the contact. Please try again."
            return false
        }
    }

    // Called by the toggles on the Circle screen
    func saveSettings() {
        guard let uid else { return }
        let snapshot = settings
        Task {
            do { try await service.saveSettings(uid: uid, settings: snapshot) }
            catch { errorMessage = "Could not save your alert settings." }
        }
    }

    func clearMessages() { errorMessage = nil }

    // MARK: - Validation

    static func normalizePhone(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        return trimmed.hasPrefix("+") ? "+" + digits : digits
    }

    static func isValidPhone(_ phone: String) -> Bool {
        let count = phone.filter(\.isNumber).count
        return (7...15).contains(count)
    }
}
