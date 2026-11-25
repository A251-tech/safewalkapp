import Foundation
import Combine
import FirebaseFirestore

// CONTROLLER: lets a contact follow one walk live (reads walks/{id}).
@MainActor
final class WalkWatcher: ObservableObject {
    @Published private(set) var walk: LiveWalk?
    @Published private(set) var loaded = false

    private let service = WalkService()
    private var listener: ListenerRegistration?
    private var currentID: String?

    func start(walkId: String) {
        guard currentID != walkId else { return }
        stop()
        currentID = walkId
        listener = service.listen(id: walkId) { [weak self] live in
            Task { @MainActor in
                self?.walk = live
                self?.loaded = true
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        currentID = nil
        walk = nil
        loaded = false
    }
}
