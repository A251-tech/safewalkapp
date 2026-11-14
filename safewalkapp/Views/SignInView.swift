import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var auth: AuthController
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AuthHeader()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome back")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Theme.navy)
                    Text("Sign in to plan your walk and keep your trusted circle close.")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.top, 28)

                LabeledField(title: "Email", placeholder: "you@example.com",
                             text: $email, keyboard: .emailAddress,
                             contentType: .emailAddress)

                LabeledField(title: "Password", placeholder: "Enter your password",
                             text: $password, isSecure: true,
                             contentType: .password)

                HStack {
                    Spacer()
                    Button("Forgot password?") {
                        Task { await auth.sendPasswordReset(email: email) }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.navy)
                }

                MessageBanner(error: auth.errorMessage, info: auth.infoMessage)

                PrimaryButton(title: "Sign in",
                              isLoading: auth.isLoading,
                              isEnabled: !email.isEmpty && !password.isEmpty) {
                    Task { await auth.signIn(email: email, password: password) }
                }

                HStack(spacing: 6) {
                    Spacer()
                    Text("New to SafeWalk?").foregroundColor(Theme.textSecondary)
                    NavigationLink("Create account") { CreateAccountView() }
                        .fontWeight(.bold)
                        .foregroundColor(Theme.navy)
                    Spacer()
                }
                .font(.system(size: 17))

                Spacer(minLength: 40)

                privacyCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { auth.clearMessages() }
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock")
                .foregroundColor(Theme.navy)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your location stays yours")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.navy)
                Text("Only share with your trusted circle when you start a walk.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

