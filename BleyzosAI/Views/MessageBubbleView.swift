import SwiftUI
import UIKit

struct MessageBubbleView: View {
    let message: Message
    let isStreaming: Bool
    /// Вызывается, когда пользователь подтверждает правку своего сообщения
    /// (новый текст). Только для message.role == .user. nil — правка недоступна.
    var onEditSubmit: ((Message, String) -> Void)? = nil
    /// Переключение версий отредактированного сообщения (-1 / +1). nil — недоступно.
    var onSwitchVariant: ((Message, Int) -> Void)? = nil

    @State private var isEditing = false
    @State private var draft = ""

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .assistant {
                // Аватар ассистента
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.bleyzosBrand)
                    .frame(width: 28, height: 28)
                    .background(Color.bleyzosBrand.opacity(0.12))
                    .clipShape(Circle())
            }

            if message.role == .user && !isEditing {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                if message.role == .user && isEditing {
                    editorView
                } else {
                    // Parts (текст + инструменты)
                    if let parts = message.parts, !parts.isEmpty {
                        ForEach(parts) { part in
                            switch part {
                            case .text(let text):
                                if !text.isEmpty {
                                    markdownText(text)
                                }
                            case .tool(let call):
                                ToolCallView(call: call)
                            }
                        }
                    } else if !message.content.isEmpty {
                        markdownText(message.content)
                    } else if isStreaming {
                        ThinkingIndicator()
                    }

                    // Artifacts
                    if let artifacts = message.artifacts, !artifacts.isEmpty {
                        ForEach(artifacts) { artifact in
                            ArtifactChip(artifact: artifact)
                        }
                    }

                    // Переключатель версий ‹ 2/3 ›
                    if message.role == .user, let total = message.variants?.count, total > 1 {
                        variantSwitcher(total: total)
                    }
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - Inline editor

    private var canSaveEdit: Bool {
        let new = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let old = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return !new.isEmpty && new != old
    }

    private var editorView: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextEditor(text: $draft)
                .font(.bleyzosBody)
                .foregroundStyle(Color.bleyzosInk)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 220)

            HStack(spacing: 8) {
                Spacer()

                Button {
                    isEditing = false
                } label: {
                    Text("Отмена")
                        .font(.bleyzosCaption.weight(.medium))
                        .foregroundStyle(Color.bleyzosMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }

                Button {
                    let text = draft
                    isEditing = false
                    onEditSubmit?(message, text)
                } label: {
                    Text("Отправить")
                        .font(.bleyzosCaption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.bleyzosBrand.opacity(canSaveEdit ? 1 : 0.4))
                        .clipShape(Capsule())
                }
                .disabled(!canSaveEdit)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.bleyzosCard)
        .clipShape(RoundedRectangle.bleyzosMedium)
        .overlay(
            RoundedRectangle.bleyzosMedium
                .stroke(Color.bleyzosBrand.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Variant switcher

    private func variantSwitcher(total: Int) -> some View {
        let current = (message.variantIndex ?? 0) + 1
        let enabled = onSwitchVariant != nil

        return HStack(spacing: 6) {
            Button {
                onSwitchVariant?(message, -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .disabled(!enabled || current <= 1)

            Text("\(current)/\(total)")
                .font(.system(size: 12).monospacedDigit())

            Button {
                onSwitchVariant?(message, 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .disabled(!enabled || current >= total)
        }
        .foregroundStyle(Color.bleyzosMuted)
    }

    /// Текст сообщения одной строкой — для копирования (склеивает .text-части).
    private var plainText: String {
        if let parts = message.parts, !parts.isEmpty {
            return parts.compactMap { part -> String? in
                if case .text(let t) = part { return t }
                return nil
            }.joined(separator: "\n")
        }
        return message.content
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = plainText
    }

    @ViewBuilder
    private func markdownText(_ text: String) -> some View {
        // Простой рендерер markdown (bold, code, ссылки)
        let parsed = parseSimpleMarkdown(text)
        Text(parsed)
            .font(.bleyzosBody)
            .foregroundStyle(message.role == .user ? .white : Color.bleyzosInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(message.role == .user ? Color.bleyzosUserBubble : Color.bleyzosAssistantBubble)
            .clipShape(RoundedRectangle.bleyzosMedium)
            .contextMenu {
                Button {
                    copyToClipboard()
                } label: {
                    Label("Копировать", systemImage: "doc.on.doc")
                }

                if message.role == .user, !isStreaming, onEditSubmit != nil {
                    Button {
                        draft = message.content
                        isEditing = true
                    } label: {
                        Label("Редактировать", systemImage: "pencil")
                    }
                }
            }
    }

    /// Безопасный однопроходный парсер: строим результат из фрагментов вместо
    /// повторной мутации AttributedString по "протухшим" диапазонам —
    /// это вызывало краш (Fatal error: Invalid index) на некоторых текстах.
    private func parseSimpleMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = Substring(text)

        while !remaining.isEmpty {
            let boldRange = remaining.range(of: "**")
            let codeRange = remaining.range(of: "`")

            guard boldRange != nil || codeRange != nil else {
                result += AttributedString(remaining)
                break
            }

            let useBold: Bool
            if let b = boldRange, let c = codeRange {
                useBold = b.lowerBound <= c.lowerBound
            } else {
                useBold = boldRange != nil
            }

            let marker = useBold ? "**" : "`"
            let markerRange = useBold ? boldRange! : codeRange!

            // Текст до маркера — как есть
            result += AttributedString(remaining[remaining.startIndex..<markerRange.lowerBound])

            let afterMarker = remaining[markerRange.upperBound...]
            if let endRange = afterMarker.range(of: marker) {
                let content = afterMarker[afterMarker.startIndex..<endRange.lowerBound]
                var attr = AttributedString(content)
                if useBold {
                    attr.font = .bleyzosBody.bold()
                } else {
                    attr.font = .bleyzosCode
                    attr.foregroundColor = Color.bleyzosBrand
                    attr.backgroundColor = Color.bleyzosAccent
                }
                result += attr
                remaining = afterMarker[endRange.upperBound...]
            } else {
                // Закрывающего маркера нет — показываем как есть
                result += AttributedString(marker)
                remaining = afterMarker
            }
        }

        return result
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let call: ToolCall
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: call.name.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(toolColor)

                    Text(call.name.displayName)
                        .font(.bleyzosCaption.weight(.medium))
                        .foregroundStyle(Color.bleyzosInk)

                    Spacer()

                    if call.status == .running {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: call.status == .ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(call.status == .ok ? Color.bleyzosSuccess : Color.bleyzosError)
                    }

                    if let ms = call.ms {
                        Text("\(ms)ms")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.bleyzosMuted)
                    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.bleyzosMuted)
                }
            }

            if expanded, let output = call.output, !output.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(output)
                        .font(.bleyzosCode)
                        .foregroundStyle(Color.bleyzosInk.opacity(0.8))
                        .padding(10)
                        .background(Color.bleyzosInk.opacity(0.04))
                        .clipShape(RoundedRectangle.bleyzosSmall)
                }
            }
        }
        .padding(12)
        .background(Color.bleyzosCard)
        .clipShape(RoundedRectangle.bleyzosMedium)
        .overlay(
            RoundedRectangle.bleyzosMedium
                .stroke(toolColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var toolColor: Color {
        switch call.status {
        case .running: return Color.bleyzosBrand
        case .ok: return Color.bleyzosSuccess
        case .error: return Color.bleyzosError
        }
    }
}

// MARK: - Artifact Chip

struct ArtifactChip: View {
    let artifact: Artifact

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: artifactIcon)
                .font(.system(size: 14))
                .foregroundStyle(Color.bleyzosBrand)

            Text(artifact.name)
                .font(.bleyzosCaption.weight(.medium))
                .foregroundStyle(Color.bleyzosInk)
                .lineLimit(1)

            Spacer()

            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 14))
                .foregroundStyle(Color.bleyzosMuted)
        }
        .padding(12)
        .background(Color.bleyzosCard)
        .clipShape(RoundedRectangle.bleyzosMedium)
        .overlay(
            RoundedRectangle.bleyzosMedium
                .stroke(Color.bleyzosBrand.opacity(0.2), lineWidth: 1)
        )
    }

    private var artifactIcon: String {
        switch artifact.kind {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .html: return "globe"
        case .markdown: return "doc.text"
        case .image: return "photo"
        case .zip: return "archivebox"
        }
    }
}

// MARK: - Thinking Indicator

struct ThinkingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.bleyzosMuted.opacity(i < dotCount ? 0.6 : 0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.bleyzosAssistantBubble)
        .clipShape(RoundedRectangle.bleyzosMedium)
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}

struct ThinkingBubble: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 16))
                .foregroundStyle(Color.bleyzosBrand)
                .frame(width: 28, height: 28)
                .background(Color.bleyzosBrand.opacity(0.12))
                .clipShape(Circle())

            ThinkingIndicator()

            Spacer()
        }
    }
}
