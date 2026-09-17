import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isStreaming: Bool

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

            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
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
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
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
    }

    private func parseSimpleMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // Bold: **text**
        while let boldRange = result.range(of: "**") {
            guard let endRange = result[boldRange.upperBound...].range(of: "**") else { break }
            let contentRange = boldRange.upperBound..<endRange.lowerBound

            result[contentRange].font = .bleyzosBody.bold()
            result.removeSubrange(endRange)
            result.removeSubrange(boldRange)
        }

        // Inline code: `code`
        while let codeRange = result.range(of: "`") {
            guard let endRange = result[codeRange.upperBound...].range(of: "`") else { break }
            let contentRange = codeRange.upperBound..<endRange.lowerBound

            result[contentRange].font = .bleyzosCode
            result[contentRange].foregroundColor = Color.bleyzosBrand
            result[contentRange].backgroundColor = Color.bleyzosAccent
            result.removeSubrange(endRange)
            result.removeSubrange(codeRange)
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
