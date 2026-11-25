import SwiftUI
import MessageUI

// A message the user is about to send from their own phone
struct ShareRequest: Identifiable {
    let id = UUID()
    let recipients: [String]
    let text: String
}

// Opens the Messages composer (real iPhone). On the simulator, or a device that can't
// send texts, it falls back to the iOS share sheet.
// MessageComposer and ShareSheet are defined in InviteSheet.swift.
struct MessageSheet: View {
    let recipients: [String]
    let text: String
    let onFinish: (Bool) -> Void

    var body: some View {
        if MFMessageComposeViewController.canSendText() {
            MessageComposer(recipients: recipients, messageText: text, onFinish: onFinish)
                .ignoresSafeArea()
        } else {
            ShareSheet(items: [text], onFinish: onFinish)
                .ignoresSafeArea()
        }
    }
}
