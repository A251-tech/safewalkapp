import Foundation
import FirebaseFirestore

enum InviteError: Error {
    case notFound, alreadyUsed, ownInvite, failed
}

// SERVICE: the only place that talks to Firestore about invites.
// Document: invites/{code}   (the code is a 6-character string like "K7M2QX")
final class InviteService {
    private let db = Firestore.firestore()
    private var ref: CollectionReference { db.collection("invites") }

    // No 0/O or 1/I/L, so a code is easy to read out and type
    private static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    static func newCode() -> String {
        String((0..<6).map { _ in Self.alphabet.randomElement() ?? "A" })
    }

    /// "k7m 2qx" -> "K7M2QX"
    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { $0.isLetter || $0.isNumber })
    }

    // MARK: - Owner side

    /// Creates an invite for one contact and returns its code
    func createInvite(ownerUid: String, ownerName: String,
                      contactId: String, contactName: String) async throws -> String {
        for _ in 0..<5 {
            let code = Self.newCode()
            let doc = ref.document(code)
            let existing = try await doc.getDocument()
            if existing.exists { continue }   // extremely rare clash: try another code
            try await doc.setData([
                "ownerUid": ownerUid,
                "ownerName": ownerName,
                "contactId": contactId,
                "contactName": contactName,
                "createdAt": FieldValue.serverTimestamp()
            ])
            return code
        }
        throw InviteError.failed
    }

    func deleteInvite(code: String) async throws {
        try await ref.document(code).delete()
    }

    /// Tells every contact who joined that a walk is (or is no longer) in progress.
    /// walkId == nil means the walk is over.
    func setActiveWalk(ownerUid: String, walkId: String?, name: String?) {
        ref.whereField("ownerUid", isEqualTo: ownerUid).getDocuments { snapshot, _ in
            for doc in snapshot?.documents ?? [] where doc.data()["acceptedBy"] != nil {
                var fields: [String: Any]
                if let walkId {
                    fields = ["activeWalkId": walkId, "activeWalkName": name ?? ""]
                } else {
                    fields = ["activeWalkId": FieldValue.delete(),
                              "activeWalkName": FieldValue.delete()]
                }
                doc.reference.updateData(fields) { _ in }
            }
        }
    }

    /// Invites I sent (so my contacts flip to "Accepted" live)
    func listenOwned(uid: String, onChange: @escaping ([Invite]) -> Void) -> ListenerRegistration {
        ref.whereField("ownerUid", isEqualTo: uid).addSnapshotListener { snapshot, _ in
            onChange((snapshot?.documents ?? []).compactMap { Self.invite(from: $0) })
        }
    }

    // MARK: - Contact side

    /// The person types the code. Marks the invite as accepted by them.
    func accept(code rawCode: String, uid: String, name: String) async throws -> Invite {
        let code = Self.normalize(rawCode)
        guard code.count == 6 else { throw InviteError.notFound }

        let doc = ref.document(code)
        let snapshot = try await doc.getDocument()
        guard let invite = Self.invite(from: snapshot) else { throw InviteError.notFound }

        if invite.ownerUid == uid { throw InviteError.ownInvite }
        if let by = invite.acceptedBy {
            if by == uid { return invite }          // already joined: fine
            throw InviteError.alreadyUsed
        }

        try await doc.updateData([
            "acceptedBy": uid,
            "acceptedName": name,
            "acceptedAt": FieldValue.serverTimestamp()
        ])
        var accepted = invite
        accepted.acceptedBy = uid
        accepted.acceptedName = name
        return accepted
    }

    /// Circles I joined (people whose walks I can follow)
    func listenJoined(uid: String, onChange: @escaping ([Invite]) -> Void) -> ListenerRegistration {
        ref.whereField("acceptedBy", isEqualTo: uid).addSnapshotListener { snapshot, _ in
            onChange((snapshot?.documents ?? []).compactMap { Self.invite(from: $0) })
        }
    }

    // MARK: - Mapping

    static func invite(from doc: DocumentSnapshot) -> Invite? {
        guard let data = doc.data(),
              let ownerUid = data["ownerUid"] as? String else { return nil }
        return Invite(id: doc.documentID,
                      ownerUid: ownerUid,
                      ownerName: data["ownerName"] as? String ?? "Someone",
                      contactId: data["contactId"] as? String ?? "",
                      contactName: data["contactName"] as? String ?? "",
                      acceptedBy: data["acceptedBy"] as? String,
                      acceptedName: data["acceptedName"] as? String,
                      activeWalkId: data["activeWalkId"] as? String,
                      activeWalkName: data["activeWalkName"] as? String)
    }
}
