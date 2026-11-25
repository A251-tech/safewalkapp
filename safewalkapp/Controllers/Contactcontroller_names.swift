import Foundation

extension ContactController {
    var firstNames: [String] {
        contacts.compactMap { $0.name.split(separator: " ").first.map(String.init) }
    }

    /// "Maya", "Maya & Jordan", "Maya, Jordan & Sam"
    var namesLine: String {
        let names = firstNames
        switch names.count {
        case 0: return "your circle"
        case 1: return names[0]
        default: return names.dropLast().joined(separator: ", ") + " & " + (names.last ?? "")
        }
    }
}
