import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let onSend: (String, [String: Data]) -> Void
    let onStop: () -> Void
    let streaming: Bool

    @FocusState private var isFocused: Bool
    @State private var showFilePicker = false
    @State private var attachedFiles: [String: Data] = [:]

    private var canSend: Bool {
        (!text.trimmingCharacters(in: .whitespaces).isEmpty || !attachedFiles.isEmpty) && !streaming
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Прикреплённые файлы
            if !attachedFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(attachedFiles.keys.sorted()), id: \.self) { name in
                            HStack(spacing: 4) {
                                Image(systemName: "doc")
                                    .font(.caption)
                                Text(name)
                                    .font(.bleyzosCaption)
                                    .lineLimit(1)
                                Button {
                                    attachedFiles.removeValue(forKey: name)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.bleyzosAccent)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }

            // Поле ввода
            HStack(alignment: .bottom, spacing: 10) {
                // Кнопка прикрепить
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.bleyzosMuted)
                        .frame(width: 36, height: 36)
                }
                .disabled(streaming)

                // Текстовое поле
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Сообщение...")
                            .foregroundStyle(Color.bleyzosMuted.opacity(0.5))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                    }

                    TextEditor(text: $text)
                        .focused($isFocused)
                        .font(.bleyzosBody)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 36, maxHeight: 120)
                        .padding(.horizontal, 2)
                        .padding(.vertical, 6)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Color.bleyzosAccent)
                .clipShape(RoundedRectangle.bleyzosMedium)

                // Кнопка отправить / стоп
                if streaming {
                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.bleyzosError)
                    }
                    .frame(width: 36, height: 36)
                } else {
                    Button {
                        let msg = text
                        let files = attachedFiles
                        text = ""
                        attachedFiles = [:]
                        onSend(msg, files)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(canSend ? Color.bleyzosBrand : Color.bleyzosMuted.opacity(0.3))
                    }
                    .disabled(!canSend)
                    .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.bleyzosBg)
        }
        .background(Color.bleyzosBg)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        attachedFiles[url.lastPathComponent] = data
                    }
                }
            }
        }
    }
}
