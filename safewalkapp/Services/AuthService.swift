import Foundation
import FirebaseAuth
import FirebaseFirestore

// SERVICE: the only place that talks to Firebase for login.
// Views never import Firebase; they go through AuthController.
final class AuthService {
    private let db = Firestore.firestore()

    func signUp(fullName: String, email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)

        // Save the name on the Auth profile
        let change = result.user.createProfileChangeRequest()
        change.displayName = fullName
        try await change.commitChanges()

        // Save the profile document in Firestore
        try await db.collection("users").document(result.user.uid).setData([
            "fullName": fullName,
            "email": email,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // Calls `handler` whenever the user signs in or out (also at app launch)
    func observeAuthState(_ handler: @escaping (FirebaseAuth.User?) -> Void) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in handler(user) }
    }

    func removeObserver(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
    }
}

