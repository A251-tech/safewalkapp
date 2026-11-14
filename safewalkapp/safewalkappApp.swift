import SwiftUI
import FirebaseCore

@main
struct SafeWalkApp: App {
    // Controller shared by every screen
    @StateObject private var auth = AuthController()

    init() {
        // Reads GoogleService-Info.plist and connects the app to Firebase
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
    }
}

