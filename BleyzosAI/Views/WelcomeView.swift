import SwiftUI

struct WelcomeView: View {
    let onPick: (String) -> Void

    // Текст и порядок — как в веб-версии (src/components/chat/welcome.tsx)
    private let suggestions: [(icon: String, title: String, subtitle: String, prompt: String)] = [
        ("chevron.left.forwardslash.chevron.right", "Напиши код", "Менеджер задач на Python — с проверкой в терминале", "Напиши скрипт на Python — менеджер задач для терминала"),
        ("globe", "Собери сайт", "Лендинг с живым HTML-предпросмотром", "Собери одностраничный сайт"),
        ("archivebox", "Собери ZIP", "Полный архив песочницы, включая скрытые файлы", "Собери zip-архив проекта со скрытыми файлами"),
        ("lightbulb", "Объясни сложное", "Что такое квантовая запутанность", "Объясни, что такое квантовая запутанность, простыми словами"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 60)

                // Заголовок — как на вебе: "Ваш умный ассистент",
                // где "ассистент" акцентным шрифтом Unbounded (bleyzosDisplay)
                VStack(spacing: 10) {
                    Text("Ваш умный")
                        .font(.bleyzosTitle)
                        .foregroundStyle(Color.bleyzosInk)
                    +
                    Text(" ассистент")
                        .font(.bleyzosDisplay)
                        .foregroundStyle(Color.bleyzosBrand)

                    Text("Задайте вопрос — помогу с текстами, кодом, планами и сложными темами")
                        .font(.bleyzosBody)
                        .foregroundStyle(Color.bleyzosMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                // Карточки-подсказки
                VStack(spacing: 12) {
                    ForEach(suggestions, id: \.title) { s in
                        Button { onPick(s.prompt) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: s.icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.bleyzosInk.opacity(0.6))
                                    .frame(width: 40, height: 40)
                                    .background(Color.bleyzosAccent)
                                    .clipShape(RoundedRectangle.bleyzosSmall)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.title)
                                        .font(.bleyzosHeadline)
                                        .foregroundStyle(Color.bleyzosInk)
                                    Text(s.subtitle)
                                        .font(.bleyzosCaption)
                                        .foregroundStyle(Color.bleyzosMuted)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.bleyzosMuted.opacity(0.4))
                            }
                            .padding(16)
                            .background(Color.bleyzosCard)
                            .clipShape(RoundedRectangle.bleyzosLarge)
                            .overlay(
                                RoundedRectangle.bleyzosLarge
                                    .stroke(Color.bleyzosBorder, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .bleyzosNoScrollEdgeEffect()
    }
}
