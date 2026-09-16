import SwiftUI

struct ChatView: View {
    @Binding var showSidebar: Bool
    @EnvironmentObject var chatService: ChatService
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?

    private let models = [
        ("gorn", "Bleyzos 2.7 Gorn", "Флагман · сложные задачи"),
        ("mini", "Bleyzos 2.7 Mini", "Быстрый · повседневные задачи"),
    ]
    @State private var selectedModel = "gorn"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Контент
            if chatService.messages.isEmpty {
                WelcomeView { prompt in
                    chatService.send(text: prompt)
                }
            } else {
                messagesView
            }

            // Ввод
            ChatInputView(
                text: $inputText,
                onSend: { text, files in
                    chatService.send(text: text, files: files)
                    inputText = ""
                },
                onStop: { chatService.stop() },
                streaming: chatService.isStreaming
            )
        }
        .background(Color.bleyzosBg)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // Кнопка меню
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showSidebar.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.bleyzosMuted)
                    .frame(width: 36, height: 36)
            }

            // Выбор модели
            Menu {
                ForEach(models, id: \.0) { model in
                    Button {
                        selectedModel = model.0
                    } label: {
                        VStack(alignment: .leading) {
                            Text(model.1)
                            Text(model.2)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(models.first { $0.0 == selectedModel }?.1 ?? "Модель")
                        .font(.bleyzosBody.weight(.medium))
                        .foregroundStyle(Color.bleyzosInk)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.bleyzosMuted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(Color.bleyzosBg.opacity(0.9))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }

    // MARK: - Messages

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(chatService.messages) { message in
                        // Пропускаем пустые assistant-сообщения в начале стриминга
                        if message.role == .assistant &&
                            message.content.isEmpty &&
                            (message.parts?.isEmpty ?? true) &&
                            chatService.isStreaming &&
                            message.id == chatService.messages.last?.id {
                            ThinkingBubble()
                                .id(message.id)
                        } else {
                            MessageBubbleView(
                                message: message,
                                isStreaming: chatService.isStreaming &&
                                    message.id == chatService.messages.last?.id
                            )
                            .id(message.id)
                        }
                    }

                    // Continue button when tool limit reached
                    if !chatService.isStreaming,
                       let lastMsg = chatService.messages.last,
                       lastMsg.role == .assistant,
                       lastMsg.content.contains("[REACHED_TOOL_LIMIT]") {
                        Button {
                            chatService.send(text: "Continue")
                        } label: {
                            Text("Continue")
                                .font(.bleyzosBody.weight(.medium))
                                .foregroundStyle(Color.bleyzosBrand)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.bleyzosBrand.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Invisible anchor for auto-scroll
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: chatService.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: chatService.streamingText) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}
