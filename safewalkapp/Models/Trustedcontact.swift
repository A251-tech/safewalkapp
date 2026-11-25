import Foundation

// MODEL: one person in the user's trusted circle.
// Stored in Firestore at users/{uid}/contacts/{contactId}
enum ContactStatus: String {
    case pending    // added by the user, invite not accepted yet
    case accepted   // contact accepted, receives walk alerts
}

struct TrustedContact: Identifiable, Equatable {
    let id: String
    var name: String
    var relationship: String
    var phone: String
    var status: ContactStatus
    var createdAt: Date?
    var invitedAt: Date?     // set when the user really sent the invite text
    var inviteCode: String?  // the code the contact types into "Join a circle"

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }
        return letters.joined()
    }

    // "••• 0142" (never show the full number in the list)
    var maskedPhone: String {
        "••• " + String(phone.filter(\.isNumber).suffix(4))
    }
}

// The three toggles on the Circle screen: users/{uid}.alertSettings
struct AlertSettings: Equatable {
    var missedCheckIn = true
    var routeDeviation = true
    var arrival = true

    var asDictionary: [String: Bool] {
        ["missedCheckIn": missedCheckIn,
         "routeDeviation": routeDeviation,
         "arrival": arrival]
    }

    init() {}

    init(dictionary: [String: Any]) {
        missedCheckIn = dictionary["missedCheckIn"] as? Bool ?? true
        routeDeviation = dictionary["routeDeviation"] as? Bool ?? true
        arrival = dictionary["arrival"] as? Bool ?? true
    }
}
