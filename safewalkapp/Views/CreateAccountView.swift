import SwiftUI
 
struct CreateAccountView: View {
    @EnvironmentObject private var auth: AuthController
    @Environment(\.dismiss) private var dismiss
 
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var agreed = false
 
    private var canSubmit: Bool {
        !fullName.isEmpty && !email.isEmpty && !password.isEmpty && !confirm.isEmpty && agreed
    }
 
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AuthHeader()
 
                VStack(alignment: .leading, spacing: 10) {
                    Text("Create your account")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Theme.navy)
                    Text("A little peace of mind for every walk.")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.top, 20)
 
                LabeledField(title: "Full name", placeholder: "Your full name",
                             text: $fullName, contentType: .name)
 
                LabeledField(title: "Email", placeholder: "you@example.com",
                             text: $email, keyboard: .emailAddress,
                             contentType: .emailAddress)
 
                VStack(alignment: .leading, spacing: 10) {
                    LabeledField(title: "Password", placeholder: "Create a password",
                                 text: $password, isSecure: true,
                                 contentType: .newPassword)
                    PasswordChecklist(password: password)
                }
 
                LabeledField(title: "Confirm password", placeholder: "Re-enter your password",
                             text: $confirm, isSecure: true,
                             contentType: .newPassword)
 
                termsRow
 
                MessageBanner(error: auth.errorMessage, info: auth.infoMessage)
 
                PrimaryButton(title: "Create account",
                              isLoading: auth.isLoading,
                              isEnabled: canSubmit) {
                    Task {
                        await auth.signUp(fullName: fullName, email: email,
                                          password: password, confirm: confirm,
                                          agreedToTerms: agreed)
                    }
                }
 
                HStack(spacing: 6) {
                    Spacer()
                    Text("Already have an account?").foregroundColor(Theme.textSecondary)
                    Button("Sign in") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundColor(Theme.navy)
                    Spacer()
                }
                .font(.system(size: 17))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { auth.clearMessages() }
    }
 
    private var termsRow: some View {
        Button { agreed.toggle() } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(agreed ? Theme.navy : Theme.field)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.navy, lineWidth: 2)
                    if agreed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 28, height: 28)
 
                // TODO: link these to real Terms / Privacy pages
                Text("I agree to the **Terms of Service** and **Privacy Policy**.")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .accessibilityLabel("Agree to Terms of Service and Privacy Policy")
        .accessibilityAddTraits(agreed ? .isSelected : [])
    }
}
 
#Preview {
    NavigationStack {
        CreateAccountView()
    }
    .environmentObject(AuthController(isPreview: true))
}
