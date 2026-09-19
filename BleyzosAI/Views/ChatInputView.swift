import SwiftUI

private struct InputHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 32
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ChatInputView: View {
    @Binding var text: String
    let onSend: (String, [String: Data]) -> Void
    let onStop: () -> Void
    let streaming: Bool

    @FocusState private var isFocused: Bool
    @State private var showFilePicker = false
    @State private var attachedFiles: [String: Data] = [:]
    @State private var measuredTextHeight: CGFloat = 32

    // Равна высоте кнопок (32pt). При HStack(alignment: .bottom) однострочный
    // текст/плейсхолдер раньше был короче кнопок (22pt) и «прилипал» к низу
    // ряда, оставляя пустой зазор сверху — визуально текст съезжал вниз
    // относительно скрепки и стрелки. Сравняв минимальную высоту с кнопками,
    // однострочный текст центруется по ним, а при росте (многострочный ввод)
    // по-прежнему растягивается вверх, оставаясь прижатым к низу.
    private let minInputHeight: CGFloat = 32
    private let maxInputHeight: CGFloat = 120
    // Общий горизонтальный отступ, единый для плейсхолдера, «линейки»-Text
    // для измерения высоты и видимого текста в TextEditor — раньше они не
    // совпадали (5/2 у плейсхолдера против 1/0 у эдитора), из-за чего текст
    // после ввода визуально «съезжал» относительно плейсхолдера и иконок.
    private let textHorizontalPadding: CGFloat = 4

    private var inputHeight: CGFloat {
        min(max(measuredTextHeight, minInputHeight), maxInputHeight)
    }

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

            // Поле ввода — карточка со светлым фоном, без обводки
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

                // Текстовое поле. Реальная высота меряется невидимым Text того
                // же шрифта через GeometryReader/PreferenceKey. У TextEditor
                // есть собственные встроенные отступы (~8pt сверху/снизу,
                // ~5pt по бокам — lineFragmentPadding), которые SwiftUI не
                // даёт убрать напрямую, поэтому компенсируем их отрицательным
                // padding, чтобы текст встал вровень с плейсхолдером.
                ZStack(alignment: .topLeading) {
                    Text(text.isEmpty ? " " : text)
                        .font(.bleyzosBody)
                        .fontWeight(.regular)
                        .padding(.horizontal, textHorizontalPadding)
                        .opacity(0)
                        .allowsHitTesting(false)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: InputHeightPreferenceKey.self,
                                    value: geo.size.height
                                )
                            }
                        )

                    if text.isEmpty {
                        Text("Спросите что-нибудь у Bleyzos AI…")
                            .font(.bleyzosBody)
                            .fontWeight(.regular)
                            .foregroundStyle(Color.bleyzosMuted.opacity(0.7))
                            .padding(.horizontal, textHorizontalPadding)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $text)
                        .focused($isFocused)
                        .font(.bleyzosBody)
                        .fontWeight(.regular)
                        .foregroundStyle(Color.bleyzosInk)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, textHorizontalPadding - 5)
                        .padding(.vertical, -8)
                        .frame(height: inputHeight)
                }
                .frame(height: inputHeight)
                .onPreferenceChange(InputHeightPreferenceKey.self) { newHeight in
                    measuredTextHeight = newHeight
                }

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
        // Фон без собственного ignoresSafeArea — растяжку под safe area делает
        // только родитель (ChatView), чтобы не было шва на стыке двух
        // независимо растянутых фоновых слоёв.
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
