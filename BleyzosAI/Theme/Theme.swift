import SwiftUI

// MARK: - Bleyzos Color Theme

extension Color {
    // Brand colors
    static let bleyzosBg = Color(red: 0.933, green: 0.922, blue: 0.898)         // #eeebe4
    static let bleyzosCard = Color(red: 0.984, green: 0.980, blue: 0.969)       // #fbfaf7
    static let bleyzosInk = Color(red: 0.122, green: 0.118, blue: 0.110)        // #1f1e1c
    static let bleyzosBrand = Color(red: 0.663, green: 0.514, blue: 0.353)      // #a9835a
    static let bleyzosMuted = Color(red: 0.435, green: 0.416, blue: 0.376)      // #6f6a60
    static let bleyzosBorder = Color(red: 0.878, green: 0.867, blue: 0.843)     // #e0ddd7
    static let bleyzosAccent = Color(red: 0.961, green: 0.953, blue: 0.937)     // #f5f3ef
    static let bleyzosSuccess = Color(red: 0.298, green: 0.686, blue: 0.420)    // #4caf50
    static let bleyzosError = Color(red: 0.906, green: 0.298, blue: 0.235)      // #e74c3c

    // Bubble colors
    static let bleyzosUserBubble = Color(red: 0.663, green: 0.514, blue: 0.353) // brand
    static let bleyzosAssistantBubble = Color(red: 0.973, green: 0.969, blue: 0.961) // #f8f7f5
}

// MARK: - Typography

extension Font {
    static let bleyzosTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let bleyzosTitleLarge = Font.system(size: 34, weight: .bold, design: .default)
    static let bleyzosHeadline = Font.system(size: 17, weight: .semibold, design: .default)
    static let bleyzosBody = Font.system(size: 16, weight: .regular, design: .default)
    static let bleyzosCaption = Font.system(size: 13, weight: .regular, design: .default)
    static let bleyzosCode = Font.system(size: 14, weight: .regular, design: .monospaced)
}

// MARK: - Rounded Rectangle Helpers

extension RoundedRectangle {
    static let bleyzosSmall = RoundedRectangle(cornerRadius: 10, style: .continuous)
    static let bleyzosMedium = RoundedRectangle(cornerRadius: 14, style: .continuous)
    static let bleyzosLarge = RoundedRectangle(cornerRadius: 18, style: .continuous)
    static let bleyzosXL = RoundedRectangle(cornerRadius: 22, style: .continuous)
}
