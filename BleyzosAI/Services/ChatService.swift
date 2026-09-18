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
    /// сессии. Оставлено для совместимости; редактирование теперь идёт через
    /// `send(text:replacing:)`, который сохраняет старую ветку как версию.
    func removeMessages(from messageId: String) {
        stop()
        guard let sIdx = sessions.firstIndex(where: { $0.id == activeSessionId }),
              let mIdx = sessions[sIdx].messages.firstIndex(where: { $0.id == messageId })
        else { return }
        sessions[sIdx].messages.removeSubrange(mIdx...)
        sessions[sIdx].updatedAt = Date()
        saveSessions()
    }

    /// Переключает версию отредактированного пользовательского сообщения
    /// (direction: -1 — предыдущая, +1 — следующая). Как в вебе: текущая ветка
    /// сохраняется в `variants`, а «хвост» выбранной версии восстанавливается.
    func switchVariant(messageId: String, direction: Int) {
        guard !isStreaming,
              let sIdx = sessions.firstIndex(where: { $0.id == activeSessionId }),
              let mIdx = sessions[sIdx].messages.firstIndex(where: { $0.id == messageId })
        else { return }

        let all = sessions[sIdx].messages
        let msg = all[mIdx]
        guard var variants = msg.variants, variants.count >= 2 else { return }

        let cur = msg.variantIndex ?? 0
        let next = cur + direction
        guard variants.indices.contains(cur), variants.indices.contains(next) else { return }

        variants[cur] = MessageVariant(content: msg.content, tail: Array(all[(mIdx + 1)...]))
        let target = variants[next]

        var switched = msg
        switched.content = target.content
        switched.variants = variants
        switched.variantIndex = next

        sessions[sIdx].messages = Array(all[..<mIdx]) + [switched] + target.tail
        saveSessions()
    }

    /// Отправка сообщения. Если задан `replaceId` — это правка существующего
    /// пользовательского сообщения: старая ветка (текст + ответы после него)
    /// сохраняется как версия, а новый текст уходит на сервер как новая версия.
    func send(text: String, files: [String: Data] = [:], replacing replaceId: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContent = replaceId != nil ? !trimmed.isEmpty : (!trimmed.isEmpty || !files.isEmpty)
        guard hasContent, !isStreaming else { return }

        var sessionId = activeSessionId
        var priorMessages: [Message] = []
        var retitle = true
        var variantInfo: (variants: [MessageVariant], index: Int)?
        var keptAttachments: [Attachment]?

        if let replaceId {
            guard let sid = activeSessionId,
                  let sIdx = sessions.firstIndex(where: { $0.id == sid }),
                  let mIdx = sessions[sIdx].messages.firstIndex(where: { $0.id == replaceId }),
                  sessions[sIdx].messages[mIdx].role == .user
            else { return }

            let all = sessions[sIdx].messages
            let oldMsg = all[mIdx]
            priorMessages = Array(all[..<mIdx])

            var list = oldMsg.variants ?? [MessageVariant(content: oldMsg.content, tail: [])]
            let cur = oldMsg.variantIndex ?? 0
            let snapshot = MessageVariant(content: oldMsg.content, tail: Array(all[(mIdx + 1)...]))
            if list.indices.contains(cur) {
                list[cur] = snapshot
            } else {
                list.append(snapshot)
            }
            list.append(MessageVariant(content: trimmed, tail: []))

            variantInfo = (list, list.count - 1)
            keptAttachments = oldMsg.attachments
            retitle = (mIdx == 0)
            sessionId = sid
        } else if let sid = sessionId, let idx = sessions.firstIndex(where: { $0.id == sid }) {
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

        let userMsg = Message(
            role: .user,
            content: trimmed,
            attachments: keptAttachments,
            variants: variantInfo?.variants,
            variantIndex: variantInfo?.index
        )
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
