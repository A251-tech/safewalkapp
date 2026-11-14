import SwiftUI
 
// "SafeWalk" title + shield icon at the top of the auth screens
struct AuthHeader: View {
    var body: some View {
        HStack {
            Text("SafeWalk")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Theme.navy)
            Spacer()
            Image(systemName: "checkmark.shield")
                .font(.system(size: 22))
                .foregroundColor(Theme.navy)
        }
        .padding(.top, 8)
    }
}
 
// Label with red asterisk + rounded field (+ eye button for passwords)
struct LabeledField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var hint: String? = nil
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
 
    @State private var reveal = false
 
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title).foregroundColor(Theme.navy)
                Text("*").foregroundColor(Theme.required)
            }
            .font(.system(size: 17, weight: .semibold))
 
            HStack {
                Group {
                    if isSecure && !reveal {
                        SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.placeholder))
                    } else {
                        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.placeholder))
                            .keyboardType(keyboard)
                    }
                }
                .accessibilityLabel(title)
                .textContentType(contentType)
                .textInputAutocapitalization(isSecure || keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled()
                .foregroundColor(Theme.navy)
 
                if isSecure {
                    Button { reveal.toggle() } label: {
                        Image(systemName: reveal ? "eye" : "eye.slash")
                            .foregroundColor(Theme.navy)
                    }
                    .accessibilityLabel(reveal ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(Theme.field)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.fieldBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
 
            if let hint {
                Text(hint)
                    .font(.footnote)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}
 
// Full-width navy button with a loading spinner
struct PrimaryButton: View {
    let title: String
    var isLoading = false
    var isEnabled = true
    let action: () -> Void
 
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundColor(.white)
            .background(Theme.navy.opacity(isEnabled ? 1 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .disabled(!isEnabled || isLoading)
    }
}
 
// Shows an error (red) or an info message (navy)
struct MessageBanner: View {
    var error: String?
    var info: String?
 
    var body: some View {
        if let error {
            banner(error, color: Theme.danger, icon: "exclamationmark.circle.fill")
        } else if let info {
            banner(info, color: Theme.navy, icon: "info.circle.fill")
        }
    }
 
    private func banner(_ text: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundColor(color)
            Text(text)
                .font(.subheadline)
                .foregroundColor(color)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
 
// Live password rules shown under the password field
struct PasswordChecklist: View {
    let password: String
 
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("At least 8 characters", PasswordRules.hasMinimumLength(password))
            row("A number", PasswordRules.hasNumber(password))
            row("A symbol, like @ or !", PasswordRules.hasSymbol(password))
        }
    }
 
    private func row(_ text: String, _ met: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundColor(met ? Theme.navy : Theme.textSecondary)
            Text(text)
                .font(.footnote)
                .foregroundColor(met ? Theme.navy : Theme.textSecondary)
        }
    }
}
 
