import Foundation
import SwiftUI

@MainActor
final class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isGuest = false
    @Published var user: AuthUser?
    @Published var isAuthenticating = false
    @Published var authError: String?
    @Published var deviceAuth: DeviceAuthResponse?
    /// Показывать модалку "Войти через Bleyzos" поверх чата (как на вебе — вход не блокирует старт).
    @Published var showAuthSheet = false

    private let apiBase: String
    private let credentialsKey = "bleyzos_credentials"
    private var pollTask: Task<Void, Never>?

    init(apiBase: String = "https://ai.bleyzos.ru") {
        self.apiBase = apiBase
        loadCredentials()
    }

    // MARK: - Public API

    /// Начать авторизацию через device flow
    func startDeviceAuth() async {
        isAuthenticating = true
        authError = nil

        do {
            let response: DeviceAuthResponse = try await APIClient.shared.post(
                url: "\(apiBase)/api/auth/device",
                body: [:]
            )
            deviceAuth = response

            // Запускаем поллинг
            startPolling(deviceCode: response.deviceCode, interval: response.interval)
        } catch {
            authError = "Не удалось начать авторизацию: \(error.localizedDescription)"
            isAuthenticating = false
        }
    }

    /// Войти как гость
    func continueAsGuest() {
        isGuest = true
        isAuthenticated = false
        user = nil
        saveCredentials()
    }

    /// Выйти
    func logout() {
        isAuthenticated = false
        user = nil
        deviceAuth = nil
        pollTask?.cancel()
        pollTask = nil
        clearCredentials()
        // После выхода остаёмся в приложении как гость — не показываем блокирующий гейт.
        isGuest = true
        saveCredentials()
    }

    /// Скопировать user_code в буфер
    func copyUserCode() {
        guard let code = deviceAuth?.userCode else { return }
        UIPasteboard.general.string = code
    }

    /// Открыть ссылку авторизации в браузере
    func openVerificationLink() {
        guard let uri = deviceAuth?.verificationUri,
              let url = URL(string: uri) else { return }
        UIApplication.shared.open(url)
    }

    /// Проверка: есть ли сохранённые credentials
    var hasStoredCredentials: Bool {
        UserDefaults.standard.string(forKey: credentialsKey) != nil
    }

    // MARK: - Polling

    private func startPolling(deviceCode: String, interval: Int) {
        pollTask?.cancel()
        pollTask = Task {
            let pollInterval = max(Double(interval), 2.0)

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                if Task.isCancelled { break }

                do {
                    let response: DeviceVerifyResponse = try await APIClient.shared.post(
                        url: "\(apiBase)/api/auth/device/verify",
                        body: ["device_code": deviceCode]
                    )

                    switch response.status {
                    case .authorized:
                        if let token = response.token, let user = response.user {
                            self.user = user
                            self.isAuthenticated = true
                            self.isGuest = false
                            self.isAuthenticating = false
                            self.deviceAuth = nil
                            self.showAuthSheet = false
                            saveCredentials(token: token, user: user)
                            pollTask?.cancel()
                            return
                        }
                    case .expired:
                        self.authError = "Код авторизации истёк. Попробуйте ещё раз."
                        self.isAuthenticating = false
                        self.deviceAuth = nil
                        pollTask?.cancel()
                        return
                    case .pending:
                        continue
                    }
                } catch {
                    // Сетевая ошибка — продолжаем polling
                    continue
                }
            }
        }
    }

    // MARK: - Keychain / UserDefaults

    private func saveCredentials(token: String? = nil, user: AuthUser? = nil) {
        if let token, let user {
            let creds = StoredCredentials(token: token, user: user)
            if let data = try? JSONEncoder().encode(creds) {
                UserDefaults.standard.set(data, forKey: credentialsKey)
            }
        }
        UserDefaults.standard.set(isGuest, forKey: "bleyzos_is_guest")
    }

    private func loadCredentials() {
        if let data = UserDefaults.standard.data(forKey: credentialsKey),
           let creds = try? JSONDecoder().decode(StoredCredentials.self, from: data) {
            self.user = creds.user
            self.isAuthenticated = true
            self.isGuest = false
        } else {
            // Как на вебе: без входа приложение сразу открывается в режиме гостя,
            // войти можно в любой момент через модалку "Войти через Bleyzos".
            self.isGuest = true
        }
    }

    private func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: credentialsKey)
        UserDefaults.standard.removeObject(forKey: "bleyzos_is_guest")
    }
}
