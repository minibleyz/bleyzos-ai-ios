import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showDeviceAuth = false

    var body: some View {
        ZStack {
            Color.bleyzosBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Логотип
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.bleyzosBrand)

                    Text("Bleyzos AI")
                        .font(.bleyzosTitleLarge)
                        .foregroundStyle(Color.bleyzosInk)

                    Text("Умный ассистент для кода,\nтекстов и задач")
                        .font(.bleyzosBody)
                        .foregroundStyle(Color.bleyzosMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 48)

                // Кнопки
                VStack(spacing: 14) {
                    // Войти
                    Button {
                        Task { await authService.startDeviceAuth() }
                        withAnimation { showDeviceAuth = true }
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 18))
                            Text("Войти через Bleyzos")
                                .font(.bleyzosHeadline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.bleyzosInk)
                        .clipShape(RoundedRectangle.bleyzosMedium)
                    }

                    // Гость
                    Button {
                        withAnimation {
                            authService.continueAsGuest()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person")
                                .font(.system(size: 18))
                            Text("Продолжить как гость")
                                .font(.bleyzosHeadline)
                        }
                        .foregroundStyle(Color.bleyzosInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.bleyzosCard)
                        .overlay(
                            RoundedRectangle.bleyzosMedium
                                .stroke(Color.bleyzosBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle.bleyzosMedium)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }

            // Device Auth Sheet
            if showDeviceAuth, authService.isAuthenticating {
                deviceAuthSheet
            }
        }
    }

    private var deviceAuthSheet: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if !authService.isAuthenticating {
                        withAnimation { showDeviceAuth = false }
                    }
                }

            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Авторизация")
                        .font(.bleyzosHeadline)
                    Spacer()
                    Button {
                        withAnimation { showDeviceAuth = false }
                        authService.logout()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.bleyzosMuted)
                    }
                }

                if let error = authService.authError {
                    // Ошибка
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.bleyzosError)
                        Text(error)
                            .font(.bleyzosBody)
                            .foregroundStyle(Color.bleyzosMuted)
                            .multilineTextAlignment(.center)

                        Button("Попробовать снова") {
                            Task { await authService.startDeviceAuth() }
                        }
                        .font(.bleyzosHeadline)
                        .foregroundStyle(Color.bleyzosBrand)
                    }
                } else if let device = authService.deviceAuth {
                    // Показываем код
                    VStack(spacing: 20) {
                        Text("Введите этот код в браузере:")
                            .font(.bleyzosBody)
                            .foregroundStyle(Color.bleyzosMuted)

                        // User code
                        Text(device.userCode)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.bleyzosInk)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color.bleyzosAccent)
                            .clipShape(RoundedRectangle.bleyzosMedium)

                        // Копировать
                        Button {
                            authService.copyUserCode()
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Копировать код")
                            }
                            .font(.bleyzosBody)
                            .foregroundStyle(Color.bleyzosBrand)
                        }

                        Divider()

                        // Открыть ссылку
                        VStack(spacing: 8) {
                            Text("Или откройте ссылку:")
                                .font(.bleyzosCaption)
                                .foregroundStyle(Color.bleyzosMuted)

                            Button {
                                authService.openVerificationLink()
                            } label: {
                                HStack {
                                    Image(systemName: "safari")
                                    Text("Открыть в браузере")
                                }
                                .font(.bleyzosHeadline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.bleyzosBrand)
                                .clipShape(RoundedRectangle.bleyzosMedium)
                            }
                        }

                        // Статус
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Ожидание авторизации...")
                                .font(.bleyzosCaption)
                                .foregroundStyle(Color.bleyzosMuted)
                        }
                        .padding(.top, 8)
                    }
                } else {
                    ProgressView("Подключение...")
                }
            }
            .padding(28)
            .background(Color.bleyzosCard)
            .clipShape(RoundedRectangle.bleyzosLarge)
            .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
            .padding(.horizontal, 24)
        }
        .animation(.easeInOut(duration: 0.25), value: authService.isAuthenticating)
        .animation(.easeInOut(duration: 0.25), value: authService.deviceAuth != nil)
    }
}
