import Foundation
import Combine
import FirebaseFirestore

// CONTROLLER: the circles I joined by typing an invite code.
@MainActor
final class JoinedCirclesController: ObservableObject {
    @Published private(set) var circles: [Invite] = []
    @Published private(set) var isJoining = false
    @Published var errorMessage: String?

    private let service = InviteService()
    private var listener: ListenerRegistration?
    private var uid: String?

    func start(uid: String) {
        guard self.uid != uid else { return }
        stop()
        self.uid = uid
        listener = service.listenJoined(uid: uid) { [weak self] list in
            Task { @MainActor in
                self?.circles = list.sorted { $0.ownerName < $1.ownerName }
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        uid = nil
        circles = []
    }

    /// Returns the invite on success, nil on failure (errorMessage explains why)
    func join(code: String, myName: String) async -> Invite? {
        errorMessage = nil
        guard let uid else {
            errorMessage = "Please sign in again."
            return nil
        }
        isJoining = true
        defer { isJoining = false }
        do {
            return try await service.accept(code: code, uid: uid,
                                            name: myName.isEmpty ? "A friend" : myName)
        } catch let error as InviteError {
            switch error {
            case .notFound:    errorMessage = "We couldn't find that code. Check it and try again."
            case .alreadyUsed: errorMessage = "That code has already been used by someone else."
            case .ownInvite:   errorMessage = "That's your own invite code. Give it to your contact instead."
            case .failed:      errorMessage = "Something went wrong. Please try again."
            }
            return nil
        } catch {
            errorMessage = "Could not join. Check your internet connection and try again."
            return nil
        }
    }
}
