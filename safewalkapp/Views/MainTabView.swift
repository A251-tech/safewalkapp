import SwiftUI
import FirebaseAuth
 
enum AppTab: Hashable {
    case walk, community, circle
}
 
// The app shell: Walk | Community | Circle
struct MainTabView: View {
    @EnvironmentObject private var auth: AuthController
    @StateObject private var contacts = ContactController()
    @StateObject private var location = LocationService()
    @State private var selection: AppTab = .walk
 
    var body: some View {
        TabView(selection: $selection) {
            HomeView(selectedTab: $selection)
                .tabItem { Label("Walk", systemImage: "location") }
                .tag(AppTab.walk)
 
            ComingSoonView(title: "Community map",
                           message: "Street ratings will appear here.")
                .tabItem { Label("Community", systemImage: "map") }
                .tag(AppTab.community)
 
            CircleView()
                .tabItem { Label("Circle", systemImage: "person.2") }
                .tag(AppTab.circle)
        }
        .tint(Theme.navy)
        .environmentObject(contacts)
        .environmentObject(location)
        // Starts listening to the user's contacts as soon as we know the uid
        .task(id: auth.currentUser?.uid) {
            if let uid = auth.currentUser?.uid { contacts.start(uid: uid) }
        }
        .onDisappear { contacts.stop() }
    }
}
 
// Temporary tab content until the real screen is built
struct ComingSoonView: View {
    let title: String
    let message: String
 
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Theme.navy)
            Text(message)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}
 
