import SwiftUI

// "Everything okay?": countdown ring + I'm safe
struct CheckInView: View {
    @EnvironmentObject private var walk: WalkController
    @EnvironmentObject private var contacts: ContactController
    @Environment(\.dismiss) private var dismiss

    let onSOS: () -> Void

    private var left: TimeInterval { walk.nextCheckInAt.timeIntervalSince(walk.now) }
    private var missed: Bool { walk.status == .missedCheckIn }
    private var progress: Double {
        missed ? 0 : min(1, max(0, left / Double(AppConfig.checkInPromptSeconds)))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("Walk check-in")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.navy)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.top, 20)

                if let place = walk.session?.destinationName {
                    Label("On your way to \(place)", systemImage: "location")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.navy)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Theme.field)
                        .clipShape(Capsule())
                }

                VStack(spacing: 8) {
                    Text(missed ? "Check-in missed" : "Everything okay?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(missed ? Theme.danger : Theme.navy)
                    Text(missed
                         ? "Tap I'm safe to tell your circle you're okay."
                         : "A quick check-in keeps your circle informed.")
                        .font(.system(size: 17))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                ring

                PrimaryButton(title: "I'm safe") {
                    walk.checkIn()
                    dismiss()
                }

                Text("Your next check-in will be in \(AppConfig.checkInMinutes) minutes.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)

                missCard

                Button { onSOS() } label: {
                    Label("Need help now? Open SOS", systemImage: "light.beacon.max")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.danger)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Theme.fieldBorder, lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(missed ? Theme.danger : Theme.navy,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            VStack(spacing: 4) {
                Text(Fmt.clock(missed ? 0 : left))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(missed ? Theme.danger : Theme.navy)
                Text("left to check in")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(width: 240, height: 240)
        .padding(.vertical, 8)
    }

    private var missCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("If you miss this check-in", systemImage: "bell")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.navy)
            Text("When the timer ends, SafeWalk will ask you to alert \(contacts.namesLine) with your last location and your live link.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.fieldBorder, lineWidth: 1))
    }
}
