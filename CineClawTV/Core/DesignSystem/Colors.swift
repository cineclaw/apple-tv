import SwiftUI

extension Color {
    // Obsidian Cinema Theme
    static let obsidianBackground = Color(red: 0.027, green: 0.035, blue: 0.055) // #07090E
    static let obsidianCard       = Color(red: 0.059, green: 0.075, blue: 0.110) // #0F131C
    static let obsidianElevated   = Color(red: 0.086, green: 0.106, blue: 0.149) // #161B26
    static let obsidianBorder     = Color(white: 0.18, opacity: 0.6)

    // Emerald Accents
    static let emeraldPrimary    = Color(red: 0.063, green: 0.725, blue: 0.506) // #10B981
    static let emeraldGlow       = Color(red: 0.063, green: 0.725, blue: 0.506).opacity(0.35)
    static let emeraldDark       = Color(red: 0.020, green: 0.350, blue: 0.230)

    // Typography
    static let textPrimary   = Color(red: 0.973, green: 0.980, blue: 0.988) // #F8FAFC
    static let textSecondary = Color(red: 0.580, green: 0.639, blue: 0.722) // #94A3B8
    static let textMuted     = Color(red: 0.392, green: 0.455, blue: 0.545) // #64748B

    // Badges & Accents
    static let ratingGold = Color(red: 0.984, green: 0.749, blue: 0.141) // #FBBF24
    static let dangerRed  = Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444
}
