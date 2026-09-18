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
                }
                .padding(.top, 8)
            }

            // Поле ввода — карточка со светлым фоном, без обводки (убрали полосу сверху)
            HStack(alignment: .bottom, spacing: 8) {
                // Кнопка прикрепить
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.bleyzosMuted)
                        .frame(width: 32, height: 32)
                }
                .disabled(streaming)

                // Текстовое поле — высота подстраивается под содержимое через
                // невидимый Text-«линейку» того же шрифта, т.к. у TextEditor
                // нет собственного intrinsic-размера и он иначе всегда
                // растягивается до maxHeight.
                ZStack(alignment: .topLeading) {
                    Text(text.isEmpty ? " " : text)
                        .font(.bleyzosBody)
                        .fontWeight(.regular)
                        .padding(.horizontal, 1)
                        .padding(.vertical, 0)
                        .opacity(0)
                        .allowsHitTesting(false)

                    if text.isEmpty {
                        Text("Спросите что-нибудь у Bleyzos AI…")
                            .font(.bleyzosBody)
                            .fontWeight(.regular)
                            .foregroundStyle(Color.bleyzosMuted.opacity(0.7))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $text)
                        .focused($isFocused)
                        .font(.bleyzosBody)
                        .fontWeight(.regular)
                        .foregroundStyle(Color.bleyzosInk)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 1)
                        .padding(.vertical, 0)
                }
                .frame(minHeight: 22, maxHeight: 120)

                // Кнопка отправить / стоп
                if streaming {
                    Button(action: onStop) {
                        Image(systemName: "square.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.bleyzosInk)
                            .frame(width: 32, height: 32)
                            .background(Color.bleyzosAccent)
                            .clipShape(RoundedRectangle.bleyzosSmall)
                    }
                } else {
                    Button {
                        let msg = text
                        let files = attachedFiles
                        text = ""
                        attachedFiles = [:]
                        onSend(msg, files)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(canSend ? Color.bleyzosInk : Color.bleyzosMuted.opacity(0.3))
                            .clipShape(RoundedRectangle.bleyzosSmall)
                    }
                    .disabled(!canSend)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.bleyzosCard)
            .clipShape(RoundedRectangle.bleyzosMedium)
            .padding(.horizontal, 12)
            .padding(.top, 10)

            Text("Bleyzos AI может ошибаться — проверяйте важную информацию.")
                .font(.system(size: 11))
                .foregroundStyle(Color.bleyzosMuted.opacity(0.8))
                .padding(.top, 6)
                .padding(.bottom, 10)
        }
        .background(Color.bleyzosBg.ignoresSafeArea(edges: .bottom))
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
