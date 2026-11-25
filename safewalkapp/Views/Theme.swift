/*import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// One place for the style guide.
enum Theme {
    static let navy          = Color(hex: 0x1E3A8A)
    static let background    = Color(hex: 0xEFF5FF)
    static let field         = Color(hex: 0xDBE8FD)
    static let fieldBorder   = Color(hex: 0xBFDBFE)
    static let textSecondary = Color(hex: 0x4A6491)
    static let danger        = Color(hex: 0xDC2626)
    static let required      = Color(hex: 0xDC2626)   // red asterisk on field labels
    static let placeholder   = Color(hex: 0x7C93BD)   // placeholder text inside fields
}
*/
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// One place for the style guide: deep teal accent, warm neutrals, and
// separate colours that always mean safe / caution / danger.
// The names below are the same as before, so no other file has to change.
enum Theme {
    // Main accent (buttons, selected tab, links, headings)
    static let navy          = Color(hex: 0x0F766E)   // deep teal

    // Neutrals
    static let background    = Color(hex: 0xF8FAF9)   // warm off-white
    static let field         = Color(hex: 0xE6F4F1)   // light teal tint for cards and fields
    static let fieldBorder   = Color(hex: 0xBFE0DA)
    static let textSecondary = Color(hex: 0x5B6B68)   // grey-green
    static let placeholder   = Color(hex: 0x8AA09B)   // placeholder text inside fields

    // Colours that carry a meaning
    static let danger        = Color(hex: 0xD64545)   // SOS, risky route, errors
    static let required      = Color(hex: 0xD64545)   // red asterisk on field labels
    static let safe          = Color(hex: 0x2E9E5B)   // safe route, accepted, arrived
    static let caution       = Color(hex: 0xE8A317)   // check carefully, waiting
}
