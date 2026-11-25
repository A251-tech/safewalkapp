import SwiftUI

// "Join a circle": the contact types the invite code they received
struct JoinCircleView: View {
    @EnvironmentObject private var joined: JoinedCirclesController
    @EnvironmentObject private var auth: AuthController
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var success: Invite?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Join a circle")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Theme.navy)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.top, 24)

                if let success {
                    successCard(success)
                } else {
                    Text("Enter the 6-character code from the invite message. You'll then be able to follow their walks and get their alerts.")
                        .font(.system(size: 17))
                        .foregroundColor(Theme.textSecondary)

                    TextField("", text: $code, prompt: Text("K7M2QX").foregroundColor(Theme.placeholder))
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .foregroundColor(Theme.navy)
                        .frame(height: 64)
                        .background(Theme.field)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.fieldBorder, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .onChange(of: code) { _, newValue in
                            let cleaned = String(InviteService.normalize(newValue).prefix(6))
                            if cleaned != newValue { code = cleaned }
                        }
                        .accessibilityLabel("Invite code")

                    MessageBanner(error: joined.errorMessage, info: nil)

                    PrimaryButton(title: "Join circle",
                                  isLoading: joined.isJoining,
                                  isEnabled: code.count == 6) {
                        Task {
                            if let invite = await joined.join(code: code, myName: auth.displayName) {
                                success = invite
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { joined.errorMessage = nil }
    }

    private func successCard(_ invite: Invite) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("You're in", systemImage: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.navy)
            Text("You joined \(invite.ownerName)'s circle. When they start a walk, you can follow it live from the Circle tab.")
                .font(.system(size: 17))
                .foregroundColor(Theme.textSecondary)
            PrimaryButton(title: "Done") { dismiss() }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
