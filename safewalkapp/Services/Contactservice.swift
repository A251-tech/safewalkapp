import Foundation
import FirebaseFirestore

// SERVICE: the only place that talks to Firestore about contacts and alert settings.
final class ContactService {
    private let db = Firestore.firestore()

    private func contactsRef(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("contacts")
    }

    // MARK: - Live listeners

    func listenContacts(uid: String,
                        onChange: @escaping (Result<[TrustedContact], Error>) -> Void) -> ListenerRegistration {
        contactsRef(uid).addSnapshotListener { snapshot, error in
            if let error {
                onChange(.failure(error))
                return
            }
            let list = (snapshot?.documents ?? [])
                .compactMap { Self.contact(from: $0) }
                .sorted { ($0.createdAt ?? .now) < ($1.createdAt ?? .now) }
            onChange(.success(list))
        }
    }

    func listenSettings(uid: String,
                        onChange: @escaping (AlertSettings) -> Void) -> ListenerRegistration {
        db.collection("users").document(uid).addSnapshotListener { snapshot, _ in
            let dict = snapshot?.data()?["alertSettings"] as? [String: Any] ?? [:]
            onChange(AlertSettings(dictionary: dict))
        }
    }

    // MARK: - Writes

    /// Returns the new contact's id
    func addContact(uid: String, name: String, relationship: String, phone: String) async throws -> String {
        let doc = try await contactsRef(uid).addDocument(data: [
            "name": name,
            "relationship": relationship,
            "phone": phone,
            "status": ContactStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return doc.documentID
    }

    func markInvited(uid: String, id: String) async throws {
        try await contactsRef(uid).document(id).updateData([
            "invitedAt": FieldValue.serverTimestamp()
        ])
    }

    func setInviteCode(uid: String, id: String, code: String) async throws {
        try await contactsRef(uid).document(id).updateData(["inviteCode": code])
    }

    /// The contact entered the code, so the owner's copy of the contact becomes "accepted"
    func markAccepted(uid: String, id: String) async throws {
        try await contactsRef(uid).document(id).updateData([
            "status": ContactStatus.accepted.rawValue,
            "acceptedAt": FieldValue.serverTimestamp()
        ])
    }

    func updateContact(uid: String, id: String, name: String,
                       relationship: String, phone: String) async throws {
        try await contactsRef(uid).document(id).updateData([
            "name": name,
            "relationship": relationship,
            "phone": phone
        ])
    }

    func deleteContact(uid: String, id: String) async throws {
        try await contactsRef(uid).document(id).delete()
    }

    func saveSettings(uid: String, settings: AlertSettings) async throws {
        try await db.collection("users").document(uid)
            .setData(["alertSettings": settings.asDictionary], merge: true)
    }

    // MARK: - Mapping

    private static func contact(from doc: QueryDocumentSnapshot) -> TrustedContact? {
        let data = doc.data()
        guard let name = data["name"] as? String else { return nil }
        return TrustedContact(
            id: doc.documentID,
            name: name,
            relationship: data["relationship"] as? String ?? "Friend",
            phone: data["phone"] as? String ?? "",
            status: ContactStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            invitedAt: (data["invitedAt"] as? Timestamp)?.dateValue(),
            inviteCode: data["inviteCode"] as? String
        )
    }
}
