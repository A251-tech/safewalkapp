import SwiftUI
import MessageUI

// What the user is about to send, and to whom
struct InviteRequest: Identifiable {
    let id = UUID()
    let contactID: String
    let phone: String
    let text: String
}

enum InviteMessage {
    static func text(senderName: String, contactName: String, code: String?) -> String {
        let first = contactName.split(separator: " ").first.map(String.init) ?? contactName
        let from = senderName.isEmpty ? "I" : "\(senderName) here. I"
        var text = "Hi \(first)! \(from) added you to my SafeWalk trusted circle. "
            + "SafeWalk shares my live location with you only while I'm on a walk, "
            + "and alerts you if I need help. "
        if let code {
            text += "To join: install SafeWalk, sign up, then open the Circle tab and tap I have an invite code "
                + "and enter this code: \(code). More info: \(AppConfig.joinLink(code))"
        } else {
            text += "Please install SafeWalk and sign up so I can add you."
        }
        return text
    }
}

// Opens the Messages composer on a real iPhone.
// The simulator and devices without Messages can't send texts, so those get the share sheet.
struct InviteSheet: View {
    let phone: String
    let messageText: String
    let onFinish: (_ sent: Bool) -> Void

    var body: some View {
        if MFMessageComposeViewController.canSendText() {
            MessageComposer(recipients: [phone], messageText: messageText, onFinish: onFinish)
                .ignoresSafeArea()
        } else {
            ShareSheet(items: [messageText], onFinish: onFinish)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Messages composer

struct MessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let messageText: String
    let onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = messageText
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (Bool) -> Void
        init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            onFinish(result == .sent)   // cancelled or failed = not sent
        }
    }
}

// MARK: - Share sheet fallback

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onFinish(completed) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
