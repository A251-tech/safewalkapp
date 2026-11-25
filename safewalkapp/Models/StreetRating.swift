/*import Foundation

// Running totals for one grid cell (a ~165 m square of map) built from its ratings.
// Ratings are stored in Firestore at ratings/{id} with NO user id (anonymous):
//   cellId, lighting (1-5), crowd (1-5), createdAt, isDemo
struct CellScore {
    var lightingTotal = 0.0
    var crowdTotal = 0.0
    var count = 0
    var hasDemo = false

    var lighting: Double { count == 0 ? 0 : lightingTotal / Double(count) }
    var crowd: Double { count == 0 ? 0 : crowdTotal / Double(count) }
}

// Used only by the demo seeder: how a cell should look in sample data
struct DemoProfile {
    let lighting: Double
    let crowd: Double
}
*/
import Foundation

// Running totals for one grid cell (a ~165 m square of map) built from its ratings.
// Ratings are stored in Firestore at ratings/{id} with NO user id (anonymous):
//   cellId, lighting (1-5), crowd (1-5), safety (1-5, optional), createdAt, isDemo
struct CellScore {
    var lightingTotal = 0.0
    var crowdTotal = 0.0
    var safetyTotal = 0.0
    var safetyCount = 0     // older ratings have no safety value, so it is counted separately
    var count = 0
    var hasDemo = false

    var lighting: Double { count == 0 ? 0 : lightingTotal / Double(count) }
    var crowd: Double { count == 0 ? 0 : crowdTotal / Double(count) }
    var safety: Double? { safetyCount == 0 ? nil : safetyTotal / Double(safetyCount) }
}

// Used only by the demo seeder: how a cell should look in sample data
struct DemoProfile {
    let lighting: Double
    let crowd: Double
}
