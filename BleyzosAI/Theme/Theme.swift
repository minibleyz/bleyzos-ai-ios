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
//
// На вебе используются шрифты Onest (текст, font-sans) и Unbounded (акценты,
// font-display) — см. globals.css / tailwind.config.ts проекта bleyzos-web.
// Файлы шрифтов лежат в /Fonts и подключаются через UIAppFonts в project.yml.
// Если по какой-то причине шрифт не встроен в бандл (например, .ttf ещё не
// добавлен в Xcode-проект), автоматически используется системный шрифт —
// приложение не падает и не выглядит сломанным.

private func customFont(_ name: String, size: CGFloat, fallbackWeight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
    if UIFont(name: name, size: size) != nil {
        return Font.custom(name, size: size)
    }
    return Font.system(size: size, weight: fallbackWeight, design: design)
}

extension Font {
    // Onest — основной текстовый шрифт (как font-sans на вебе)
    static let bleyzosTitle = customFont("Onest-Bold", size: 28, fallbackWeight: .bold)
    static let bleyzosTitleLarge = customFont("Onest-Bold", size: 34, fallbackWeight: .bold)
    static let bleyzosHeadline = customFont("OnestSemiBold-Regular", size: 17, fallbackWeight: .semibold)
    static let bleyzosBody = customFont("Onest-Regular", size: 16, fallbackWeight: .regular)
    static let bleyzosCaption = customFont("Onest-Regular", size: 13, fallbackWeight: .regular)
    static let bleyzosCode = Font.system(size: 14, weight: .regular, design: .monospaced)

    // Unbounded — акцентный шрифт (как font-display на вебе), для заголовка Welcome
    static let bleyzosDisplay = customFont("Unbounded-Bold", size: 32, fallbackWeight: .bold)
    static let bleyzosDisplayBlack = customFont("UnboundedBlack-Regular", size: 32, fallbackWeight: .black)
}

// MARK: - Rounded Rectangle Helpers

extension RoundedRectangle {
    static let bleyzosSmall = RoundedRectangle(cornerRadius: 10, style: .continuous)
    static let bleyzosMedium = RoundedRectangle(cornerRadius: 14, style: .continuous)
    static let bleyzosLarge = RoundedRectangle(cornerRadius: 18, style: .continuous)
    static let bleyzosXL = RoundedRectangle(cornerRadius: 22, style: .continuous)
}

// MARK: - Scroll Edge Effect
//
// Заглушка-но-оп: в текущем SDK (iOS 18.5, Xcode 16.4) модификатора
// scrollEdgeEffectStyle не существует — предыдущая попытка не компилировалась.
// Оставляем хелпер как проходную точку, чтобы не трогать места вызова,
// пока не найдём реальную причину полосы над полем ввода.
extension View {
    @ViewBuilder
    func bleyzosNoScrollEdgeEffect() -> some View {
        self
    }
}
