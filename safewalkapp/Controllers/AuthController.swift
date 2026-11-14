import Foundation
import Combine
import FirebaseAuth
 
// CONTROLLER: validation rules, loading state, error messages.
// Views call these functions and show the @Published values.
@MainActor
final class AuthController: ObservableObject {
    @Published var currentUser: FirebaseAuth.User?
    @Published var displayName: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
 
    private let service = AuthService()
    private var handle: AuthStateDidChangeListenerHandle?
 
    // isPreview = true is used by Xcode Previews, where Firebase is not started
    init(isPreview: Bool = false) {
        if isPreview { return }
 
        // Restores the saved session instantly at launch
        currentUser = Auth.auth().currentUser
        displayName = currentUser?.displayName ?? ""
 
        handle = service.observeAuthState { [weak self] user in
            Task { @MainActor in
                self?.currentUser = user
                self?.displayName = user?.displayName ?? ""
            }
        }
    }
 
    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }
 
    // MARK: - Actions
 
    func signIn(email: String, password: String) async {
        clearMessages()
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
 
        guard Self.isValidEmail(mail) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            return
        }
 
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.signIn(email: mail, password: password)
        } catch {
            errorMessage = message(for: error)
        }
    }
 
    func signUp(fullName: String, email: String, password: String,
                confirm: String, agreedToTerms: Bool) async {
        clearMessages()
        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
 
        guard !name.isEmpty else {
            errorMessage = "Please enter your full name."
            return
        }
        guard Self.isValidEmail(mail) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        let missing = PasswordRules.problems(password)
        guard missing.isEmpty else {
            errorMessage = "Your password still needs: " + missing.joined(separator: ", ") + "."
            return
        }
        guard password == confirm else {
            errorMessage = "Passwords do not match."
            return
        }
        guard agreedToTerms else {
            errorMessage = "Please agree to the Terms of Service and Privacy Policy."
            return
        }
 
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.signUp(fullName: name, email: mail, password: password)
            displayName = name
        } catch {
            errorMessage = message(for: error)
        }
    }
 
    func sendPasswordReset(email: String) async {
        clearMessages()
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isValidEmail(mail) else {
            errorMessage = "Enter your email above, then tap Forgot password."
            return
        }
        do {
            try await service.sendPasswordReset(email: mail)
            infoMessage = "If an account exists for that email, a reset link is on its way."
        } catch {
            errorMessage = message(for: error)
        }
    }
 
    func signOut() {
        do { try service.signOut() }
        catch { errorMessage = "Could not sign out. Please try again." }
    }
 
    func clearMessages() {
        errorMessage = nil
        infoMessage = nil
    }
 
    // MARK: - Validation
 
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
    }
 
    // MARK: - Friendly error messages
 
    // Firebase puts a number in every auth error. We read that number directly,
    // so this works on every Firebase version.
    private func message(for error: Error) -> String {
        let nsError = error as NSError
        // Shows the real reason in Xcode's console (bottom panel) while developing
        print("Auth error ->", nsError.domain, nsError.code, nsError.localizedDescription)
 
        guard nsError.domain == "FIRAuthErrorDomain" else {
            return "Something went wrong (\(nsError.domain) \(nsError.code)). Please try again."
        }
        switch nsError.code {
        case 17008:                 // invalid email
            return "That email address is not valid."
        case 17007:                 // email already in use
            return "An account with this email already exists. Try signing in."
        case 17026:                 // weak password (Firebase's own rules)
            return "Firebase says this password is too weak. Use a longer one with a number and a symbol."
        case 17009, 17004, 17011:   // wrong password / invalid credential / user not found
            return "Incorrect email or password."
        case 17020:                 // network error
            return "No internet connection. Check your network and try again."
        case 17010:                 // too many requests
            return "Too many attempts. Please wait a moment and try again."
        case 17005:                 // user disabled
            return "This account has been disabled."
        case 17006:                 // operation not allowed
            return "Email/password sign-in is not turned on in Firebase. Enable it under Authentication > Sign-in method."
        case 17999:                 // internal error (usually a setup problem)
            return "Firebase setup problem (internal error). Check GoogleService-Info.plist and the Bundle ID."
        default:
            return "Something went wrong (error \(nsError.code)). Please try again."
        }
    }
}
 
// Password rules in one place, used by the controller and the live checklist
enum PasswordRules {
    static func hasMinimumLength(_ password: String) -> Bool {
        password.count >= 8
    }
 
    static func hasNumber(_ password: String) -> Bool {
        password.rangeOfCharacter(from: .decimalDigits) != nil
    }
 
    static func hasSymbol(_ password: String) -> Bool {
        let symbols = CharacterSet.alphanumerics.inverted.subtracting(.whitespacesAndNewlines)
        return password.rangeOfCharacter(from: symbols) != nil
    }
 
    // What is still missing, in plain words
    static func problems(_ password: String) -> [String] {
        var list: [String] = []
        if !hasMinimumLength(password) { list.append("at least 8 characters") }
        if !hasNumber(password) { list.append("a number") }
        if !hasSymbol(password) { list.append("a symbol (like @ or !)") }
        return list
    }
}
 
