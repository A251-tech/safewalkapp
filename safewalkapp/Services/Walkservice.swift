import Foundation
import CoreLocation
import FirebaseFirestore

// SERVICE: the only place that talks to Firestore about walks.
// Document: walks/{walkId}. Only these fields are allowed by the security rules:
// ownerUid, ownerName, destinationName, status, startedAt, expectedArrival,
// lastLocation, lastUpdated, checkInMinutes, nextCheckInAt
final class WalkService {
    private let db = Firestore.firestore()

    private func ref(_ id: String) -> DocumentReference {
        db.collection("walks").document(id)
    }

    /// 36 random hex characters. Long enough that nobody can guess another walk's link.
    static func newToken() -> String {
        (0..<18).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }

    // MARK: - Writes

    /// Creates the walk. If the phone is offline the write is queued by Firestore,
    /// so after 8 seconds we carry on instead of leaving the user stuck on a spinner.
    func create(id: String, ownerUid: String, ownerFirstName: String, destinationName: String,
                expectedArrival: Date, checkInMinutes: Int, nextCheckInAt: Date,
                start: CLLocationCoordinate2D?) async throws {
        var data: [String: Any] = [
            "ownerUid": ownerUid,
            "ownerName": ownerFirstName,
            "destinationName": destinationName,
            "status": WalkStatus.active.rawValue,
            "startedAt": FieldValue.serverTimestamp(),
            "expectedArrival": Timestamp(date: expectedArrival),
            "lastUpdated": FieldValue.serverTimestamp(),
            "checkInMinutes": checkInMinutes,
            "nextCheckInAt": Timestamp(date: nextCheckInAt)
        ]
        if let start {
            data["lastLocation"] = GeoPoint(latitude: start.latitude, longitude: start.longitude)
        }

        let reference = ref(id)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = Once()
            reference.setData(data) { error in
                once.run {
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                once.run { continuation.resume() }
            }
        }
    }

    /// Fire and forget: Firestore keeps unsent writes and delivers them when the network returns.
    func updateLocation(id: String, coordinate: CLLocationCoordinate2D) {
        ref(id).updateData([
            "lastLocation": GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude),
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { _ in }
    }

    func setStatus(id: String, status: WalkStatus) {
        ref(id).updateData([
            "status": status.rawValue,
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { _ in }
    }

    func checkedIn(id: String, nextCheckInAt: Date) {
        ref(id).updateData([
            "status": WalkStatus.active.rawValue,
            "nextCheckInAt": Timestamp(date: nextCheckInAt),
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { _ in }
    }

    /// A contact follows a walk: calls `onChange` whenever the walk document changes.
    /// Gives nil if the walk does not exist (any more).
    func listen(id: String, onChange: @escaping (LiveWalk?) -> Void) -> ListenerRegistration {
        ref(id).addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data() else {
                onChange(nil)
                return
            }
            let point = data["lastLocation"] as? GeoPoint
            onChange(LiveWalk(
                status: WalkStatus(rawValue: data["status"] as? String ?? "") ?? .active,
                destinationName: data["destinationName"] as? String ?? "their destination",
                coordinate: point.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                lastUpdated: (data["lastUpdated"] as? Timestamp)?.dateValue(),
                nextCheckInAt: (data["nextCheckInAt"] as? Timestamp)?.dateValue()))
        }
    }

    /// Ends sharing: sets the final status and removes the location so an old link shows nothing.
    func finish(id: String, status: WalkStatus) {
        ref(id).updateData([
            "status": status.rawValue,
            "lastLocation": FieldValue.delete(),
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { _ in }
    }
}

// Makes sure a continuation is resumed only once (completion handler vs. timeout)
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ block: () -> Void) {
        lock.lock()
        let first = !done
        done = true
        lock.unlock()
        if first { block() }
    }
}
