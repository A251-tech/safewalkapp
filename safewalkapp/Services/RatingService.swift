/*import Foundation
import FirebaseFirestore

// SERVICE: the only place that talks to Firestore about street ratings.
final class RatingService {
    private let db = Firestore.firestore()
    private var ref: CollectionReference { db.collection("ratings") }

    // MARK: - Reading

    /// Totals per cell for the given cells. Firestore allows 30 values per `in` query.
    func fetchScores(cells: [String]) async throws -> [String: CellScore] {
        var result: [String: CellScore] = [:]
        let unique = Array(Set(cells))

        for start in stride(from: 0, to: unique.count, by: 30) {
            let chunk = Array(unique[start..<min(start + 30, unique.count)])
            let snapshot = try await ref.whereField("cellId", in: chunk).getDocuments()

            for doc in snapshot.documents {
                let data = doc.data()
                guard let cell = data["cellId"] as? String,
                      let lighting = data["lighting"] as? Int,
                      let crowd = data["crowd"] as? Int else { continue }

                var score = result[cell] ?? CellScore()
                score.lightingTotal += Double(lighting)
                score.crowdTotal += Double(crowd)
                score.count += 1
                if data["isDemo"] as? Bool == true { score.hasDemo = true }
                result[cell] = score
            }
        }
        return result
    }

    // MARK: - Demo data (every document is flagged isDemo: true)

    func seedDemo(profiles: [String: DemoProfile]) async throws {
        var docs: [[String: Any]] = []
        for (cell, profile) in profiles {
            for i in 0..<4 {
                let h = Grid.stableHash("\(cell)#\(i)")
                let jitterLight = Double(h % 3 - 1) * 0.7
                let jitterCrowd = Double((h / 3) % 3 - 1) * 0.7
                let hoursAgo = Double(h % 48)
                docs.append([
                    "cellId": cell,
                    "lighting": Self.clamp(profile.lighting + jitterLight),
                    "crowd": Self.clamp(profile.crowd + jitterCrowd),
                    "createdAt": Timestamp(date: Date().addingTimeInterval(-hoursAgo * 3600)),
                    "isDemo": true
                ])
            }
        }

        for start in stride(from: 0, to: docs.count, by: 400) {
            let batch = db.batch()
            for data in docs[start..<min(start + 400, docs.count)] {
                batch.setData(data, forDocument: ref.document())
            }
            try await batch.commit()
        }
    }

    func clearDemo() async throws {
        let snapshot = try await ref.whereField("isDemo", isEqualTo: true).getDocuments()
        let documents = snapshot.documents
        for start in stride(from: 0, to: documents.count, by: 400) {
            let batch = db.batch()
            for doc in documents[start..<min(start + 400, documents.count)] {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }
    }

    private static func clamp(_ value: Double) -> Int {
        Int(min(5, max(1, value.rounded())))
    }
}
*/
import Foundation
import FirebaseFirestore

// SERVICE: the only place that talks to Firestore about street ratings.
final class RatingService {
    private let db = Firestore.firestore()
    private var ref: CollectionReference { db.collection("ratings") }

    // MARK: - Reading

    /// Totals per cell for the given cells. Firestore allows 30 values per `in` query.
    func fetchScores(cells: [String]) async throws -> [String: CellScore] {
        var result: [String: CellScore] = [:]
        let unique = Array(Set(cells))

        for start in stride(from: 0, to: unique.count, by: 30) {
            let chunk = Array(unique[start..<min(start + 30, unique.count)])
            let snapshot = try await ref.whereField("cellId", in: chunk).getDocuments()

            for doc in snapshot.documents {
                let data = doc.data()
                guard let cell = data["cellId"] as? String,
                      let lighting = data["lighting"] as? Int,
                      let crowd = data["crowd"] as? Int else { continue }
                let safety = data["safety"] as? Int   // missing in older ratings

                var score = result[cell] ?? CellScore()
                score.lightingTotal += Double(lighting)
                score.crowdTotal += Double(crowd)
                if let safety {
                    score.safetyTotal += Double(safety)
                    score.safetyCount += 1
                }
                score.count += 1
                if data["isDemo"] as? Bool == true { score.hasDemo = true }
                result[cell] = score
            }
        }
        return result
    }

    // MARK: - Writing (a real rating from a person; no user id is stored)

    func submit(cellId: String, lighting: Int, crowd: Int, safety: Int) async throws {
        _ = try await ref.addDocument(data: Self.ratingData(cellId, lighting, crowd, safety))
    }

    /// After a walk: the whole route gets the walker's three scores. Spots the walker flagged
    /// are saved as very dark and unsafe instead (lighting 1, safety 1).
    func submitWalk(cells: [String], lighting: Int, crowd: Int, safety: Int,
                    flagged: Set<String>) async throws {
        for start in stride(from: 0, to: cells.count, by: 400) {
            let batch = db.batch()
            for cell in cells[start..<min(start + 400, cells.count)] {
                let isFlagged = flagged.contains(cell)
                let data = Self.ratingData(cell,
                                           isFlagged ? 1 : lighting,
                                           crowd,
                                           isFlagged ? 1 : safety)
                batch.setData(data, forDocument: ref.document())
            }
            try await batch.commit()
        }
    }

    private static func ratingData(_ cell: String, _ lighting: Int, _ crowd: Int, _ safety: Int) -> [String: Any] {
        ["cellId": cell,
         "lighting": lighting,
         "crowd": crowd,
         "safety": safety,
         "createdAt": Timestamp(date: Date())]
    }

    // MARK: - Demo data (every document is flagged isDemo: true)

    func seedDemo(profiles: [String: DemoProfile]) async throws {
        var docs: [[String: Any]] = []
        for (cell, profile) in profiles {
            for i in 0..<4 {
                let h = Grid.stableHash("\(cell)#\(i)")
                let jitterLight = Double(h % 3 - 1) * 0.7
                let jitterCrowd = Double((h / 3) % 3 - 1) * 0.7
                let hoursAgo = Double(h % 48)
                docs.append([
                    "cellId": cell,
                    "lighting": Self.clamp(profile.lighting + jitterLight),
                    "crowd": Self.clamp(profile.crowd + jitterCrowd),
                    "safety": Self.clamp((profile.lighting + profile.crowd) / 2 + jitterLight),
                    "createdAt": Timestamp(date: Date().addingTimeInterval(-hoursAgo * 3600)),
                    "isDemo": true
                ])
            }
        }

        for start in stride(from: 0, to: docs.count, by: 400) {
            let batch = db.batch()
            for data in docs[start..<min(start + 400, docs.count)] {
                batch.setData(data, forDocument: ref.document())
            }
            try await batch.commit()
        }
    }

    func clearDemo() async throws {
        let snapshot = try await ref.whereField("isDemo", isEqualTo: true).getDocuments()
        let documents = snapshot.documents
        for start in stride(from: 0, to: documents.count, by: 400) {
            let batch = db.batch()
            for doc in documents[start..<min(start + 400, documents.count)] {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }
    }

    private static func clamp(_ value: Double) -> Int {
        Int(min(5, max(1, value.rounded())))
    }
}
