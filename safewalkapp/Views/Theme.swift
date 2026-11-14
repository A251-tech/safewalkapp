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
 
// One place for the style guide.
// These values were read directly from your Sign in design.
enum Theme {
    static let navy          = Color(hex: 0x1E3A8A)   // titles, labels, links, button
    static let background    = Color(hex: 0xEFF6FF)   // screen background
    static let field         = Color(hex: 0xDBEAFE)   // text fields, privacy card
    static let fieldBorder   = Color(hex: 0xBFDBFE)   // field outline
    static let textSecondary = Color(hex: 0x49658C)   // subtitles, hints, body text
    static let placeholder   = Color(hex: 0x547099)   // text inside empty fields
    static let required      = Color(hex: 0xB91C1C)   // red asterisk (*)
    static let danger        = Color(hex: 0xDC2626)   // errors and SOS red
}
 
