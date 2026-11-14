/*import SwiftUI

// Decides which screen to show: signed in -> app, signed out -> Sign in
struct RootView: View {
    @EnvironmentObject private var auth: AuthController

    var body: some View {
        if auth.currentUser != nil {
            HomePlaceholderView()
        } else {
            NavigationStack {
                SignInView()
            }
        }
    }
}

// Temporary screen so you can see login worked.
// Replace with the real Home screen (TabView) in the next step.
struct HomePlaceholderView: View {
    @EnvironmentObject private var auth: AuthController

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(Theme.navy)
            Text("You're signed in")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.navy)
            if !auth.displayName.isEmpty {
                Text("Hi, \(auth.displayName)")
                    .foregroundColor(Theme.textSecondary)
            }
            PrimaryButton(title: "Sign out") { auth.signOut() }
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

*/
import SwiftUI
 
// Decides which screen to show: signed in -> app, signed out -> Sign in
struct RootView: View {
    @EnvironmentObject private var auth: AuthController
 
    var body: some View {
        if auth.currentUser != nil {
            MainTabView()
        } else {
            NavigationStack {
                SignInView()
            }
        }
    }
}
 
