/*import Foundation
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
    private var contactsListener: ListenerRegistration?
    private var settingsListener: ListenerRegistration?
    private var uid: String?

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
            }
        }
        settingsListener = service.listenSettings(uid: uid) { [weak self] value in
            Task { @MainActor in self?.settings = value }
        }
    }

    func stop() {
        contactsListener?.remove()
        settingsListener?.remove()
        contactsListener = nil
        settingsListener = nil
        uid = nil
        contacts = []
        hasLoaded = false
    }

    // MARK: - Actions

    var canAddMore: Bool { contacts.count < Self.maxContacts }

    /// Adds a new contact (existing == nil) or updates one. Returns true on success.
    func save(existing: TrustedContact?, name: String, relationship: String, phone: String) async -> Bool {
        errorMessage = nil
        guard let uid else { return false }

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = Self.normalizePhone(phone)

        guard !cleanName.isEmpty else {
            errorMessage = "Please enter the contact's name."
            return false
        }
        guard Self.isValidPhone(cleanPhone) else {
            errorMessage = "Please enter a valid phone number."
            return false
        }
        let isDuplicate = contacts.contains { $0.phone == cleanPhone && $0.id != existing?.id }
        guard !isDuplicate else {
            errorMessage = "This number is already in your trusted circle."
            return false
        }
        if existing == nil && !canAddMore {
            errorMessage = "You can have up to \(Self.maxContacts) trusted contacts."
            return false
        }

        isLoading = true
        defer { isLoading = false }
        do {
            if let existing {
                try await service.updateContact(uid: uid, id: existing.id, name: cleanName,
                                                relationship: relationship, phone: cleanPhone)
            } else {
                try await service.addContact(uid: uid, name: cleanName,
                                             relationship: relationship, phone: cleanPhone)
            }
            return true
        } catch {
            errorMessage = "Could not save the contact. Please try again."
            return false
        }
    }

    func delete(_ contact: TrustedContact) async -> Bool {
        guard let uid else { return false }
        isLoading = true
        defer { isLoading = false }
        do {
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
*/
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
    private var contactsListener: ListenerRegistration?
    private var settingsListener: ListenerRegistration?
    private var uid: String?

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
            }
        }
        settingsListener = service.listenSettings(uid: uid) { [weak self] value in
            Task { @MainActor in self?.settings = value }
        }
    }

    func stop() {
        contactsListener?.remove()
        settingsListener?.remove()
        contactsListener = nil
        settingsListener = nil
        uid = nil
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

    func delete(_ contact: TrustedContact) async -> Bool {
        guard let uid else { return false }
        isLoading = true
        defer { isLoading = false }
        do {
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
