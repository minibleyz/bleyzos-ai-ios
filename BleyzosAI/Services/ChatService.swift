import Foundation
import SwiftUI

@MainActor
final class ChatService: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var activeSessionId: String?
    @Published var isStreaming = false
    @Published var streamingText = ""

    let apiBase: String
    private let storageKey = "bleyzos_chat_sessions"
    private var streamTask: Task<Void, Never>?

    init(apiBase: String = "https://ai.bleyzos.ru") {
        self.apiBase = apiBase
        loadSessions()
    }

    // MARK: - Computed

    var activeSession: ChatSession? {
        sessions.first { $0.id == activeSessionId }
    }

    var messages: [Message] {
        activeSession?.messages ?? []
    }

    // MARK: - Actions

    func newChat() {
        stop()
        activeSessionId = nil
        streamingText = ""
    }

    func selectSession(_ id: String) {
        stop()
        activeSessionId = id
        streamingText = ""
    }

    func deleteSession(_ id: String) {
        if id == activeSessionId { stop() }
        sessions.removeAll { $0.id == id }
        if activeSessionId == id {
            activeSessionId = sessions.first?.id
        }
        saveSessions()
    }

    /// Удаляет сообщение с указанным id и всё, что шло после него, в активной
    /// сессии. Используется для редактирования: пользователь правит текст
    /// своего сообщения, а старый "хвост" (это сообщение + последующий ответ
    /// ассистента) убирается, после чего отредактированный текст отправляется
    /// заново через `send`.
    func removeMessages(from messageId: String) {
        stop()
        guard let sIdx = sessions.firstIndex(where: { $0.id == activeSessionId }),
              let mIdx = sessions[sIdx].messages.firstIndex(where: { $0.id == messageId })
        else { return }
        sessions[sIdx].messages.removeSubrange(mIdx...)
        sessions[sIdx].updatedAt = Date()
        saveSessions()
    }

    func send(text: String, files: [String: Data] = [:]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !files.isEmpty, !isStreaming else { return }

        var sessionId = activeSessionId
        var priorMessages: [Message] = []
        var retitle = true

        if let sid = sessionId, let idx = sessions.firstIndex(where: { $0.id == sid }) {
            priorMessages = sessions[idx].messages
            retitle = priorMessages.isEmpty
        } else {
            let newSession = ChatSession(
                title: makeTitle(trimmed.isEmpty ? files.keys.joined(separator: ", ") : trimmed)
            )
            sessionId = newSession.id
            sessions.insert(newSession, at: 0)
            activeSessionId = newSession.id
            priorMessages = []
            retitle = true
        }

        guard let sessionId else { return }

        let userMsg = Message(role: .user, content: trimmed)
        let assistantMsg = Message(role: .assistant, content: "")

        // Обновляем UI
        if let idx = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[idx].messages = priorMessages + [userMsg, assistantMsg]
            if retitle {
                sessions[idx].title = makeTitle(trimmed.isEmpty ? files.keys.joined(separator: ", ") : trimmed)
            }
            sessions[idx].updatedAt = Date()
        }

        isStreaming = true
        streamingText = ""

        let apiMessages = (priorMessages + [userMsg]).map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        }

        streamTask = Task {
            let stream = APIClient.shared.streamChat(
                url: "\(apiBase)/api/chat/",
                messages: apiMessages,
                sessionId: sessionId,
                files: files.isEmpty ? nil : files
            )

            do {
                for try await event in stream {
                    if Task.isCancelled { break }

                    switch event {
                    case .text(let v):
                        streamingText += v
                        updateAssistant(sessionId: sessionId, assistantId: assistantMsg.id) { msg in
                            msg.content += v
                        }

                    case .tool(let id, let name, let args):
                        let call = ToolCall(id: id, name: name, args: args, status: .running)
                        updateAssistant(sessionId: sessionId, assistantId: assistantMsg.id) { msg in
                            if msg.parts == nil { msg.parts = [] }
                            msg.parts!.append(.tool(call))
                        }

                    case .toolRes(let id, let ok, let output, let ms):
                        updateAssistant(sessionId: sessionId, assistantId: assistantMsg.id) { msg in
                            guard var parts = msg.parts else { return }
                            for i in parts.indices {
                                if case .tool(var call) = parts[i], call.id == id {
                                    call.status = ok ? .ok : .error
                                    call.output = output
                                    call.ms = ms
                                    parts[i] = .tool(call)
                                }
                            }
                            msg.parts = parts
                        }

                    case .artifact(let name, let kind, let content, let url):
                        let art = Artifact(name: name, kind: kind, content: content, url: url)
                        updateAssistant(sessionId: sessionId, assistantId: assistantMsg.id) { msg in
                            if msg.artifacts == nil { msg.artifacts = [] }
                            msg.artifacts!.append(art)
                        }

                    case .done:
                        break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    updateAssistant(sessionId: sessionId, assistantId: assistantMsg.id) { msg in
                        if msg.content.isEmpty {
                            msg.content = "Не удалось получить ответ. Попробуйте ещё раз."
                        }
                    }
                }
            }

            isStreaming = false
            streamingText = ""
            saveSessions()
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        streamingText = ""
    }

    // MARK: - Private

    private func updateAssistant(sessionId: String, assistantId: String, _ mutate: (inout Message) -> Void) {
        guard let sIdx = sessions.firstIndex(where: { $0.id == sessionId }),
              let mIdx = sessions[sIdx].messages.firstIndex(where: { $0.id == assistantId })
        else { return }
        mutate(&sessions[sIdx].messages[mIdx])
    }

    private func makeTitle(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return clean.count > 44 ? String(clean.prefix(44)) + "…" : clean
    }

    // MARK: - Persistence

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let loaded = try? JSONDecoder().decode([ChatSession].self, from: data)
        else { return }
        sessions = loaded.sorted { $0.updatedAt > $1.updatedAt }
        activeSessionId = sessions.first?.id
    }
}
