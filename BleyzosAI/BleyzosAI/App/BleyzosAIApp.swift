import SwiftUI

@main
struct BleyzosAIApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var chatService = ChatService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(chatService)
                .onOpenURL { url in
                    // Обработка deep link если нужно
                    print("Deep link: \(url)")
                }
        }
    }
}
