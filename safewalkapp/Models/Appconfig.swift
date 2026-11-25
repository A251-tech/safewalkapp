import Foundation

// One place for the numbers and links you may want to change.
enum AppConfig {
    // After `firebase deploy`, your viewer page lives at https://<your-project-id>.web.app
    // Replace YOUR-PROJECT-ID (Firebase console > Project settings shows it).
    static let walkLinkBase = "https://YOUR-PROJECT-ID.web.app/walk?w="

    // India's national emergency number. Use "911" for the US.
    static let emergencyNumber = "112"

    static let checkInMinutes = 5          // time between check-ins
    static let checkInPromptSeconds = 60   // how long the user has to answer a check-in
    static let arrivalRadius = 30.0        // meters from the destination = arrived
    static let deviationRadius = 100.0     // meters from the route = off route
    static let writeInterval = 8.0         // seconds between location writes to Firestore

    static func walkLink(_ walkID: String) -> String { walkLinkBase + walkID }

    // The small page that shows the invite code and how to join (web/join.html)
    static let joinLinkBase = "https://YOUR-PROJECT-ID.web.app/join?c="
    static func joinLink(_ code: String) -> String { joinLinkBase + code }
}

enum Fmt {
    /// 125 seconds -> "2:05"
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
