import Foundation

// MODEL: one invite to join someone's trusted circle.
// Stored in Firestore at invites/{code}. The 6-character code is the document id.
struct Invite: Identifiable, Equatable {
    let id: String              // the invite code, e.g. "K7M2QX"
    let ownerUid: String        // who sent the invite
    let ownerName: String
    let contactId: String       // which contact (in the owner's list) it belongs to
    let contactName: String
    var acceptedBy: String?     // uid of the person who entered the code
    var acceptedName: String?
    var activeWalkId: String?   // set while the owner is on a walk
    var activeWalkName: String?

    var isAccepted: Bool { acceptedBy != nil }
}
