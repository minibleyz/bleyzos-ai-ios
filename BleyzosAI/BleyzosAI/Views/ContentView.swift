import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var chatService: ChatService
    @State private var showSidebar = false

    var body: some Group {
        if !authService.isAuthenticated && !authService.isGuest {
            // Не авторизован — показываем онбординг
            AuthView()
        } else {
            // Авторизован — показываем чат
            mainChatView
        }
    }

    private var mainChatView: some View {
        ZStack {
            // Основной чат
            ChatView(showSidebar: $showSidebar)
                .environmentObject(chatService)

            // Мобильный сайдбар
            if showSidebar {
                sidebarOverlay
            }
        }
    }

    private var sidebarOverlay: some View {
        ZStack(alignment: .leading) {
            // Затемнение
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSidebar = false
                    }
                }

            // Сайдбар
            SidebarView(showSidebar: $showSidebar)
                .environmentObject(chatService)
                .environmentObject(authService)
                .frame(width: 300)
                .transition(.move(edge: .leading))
        }
        .zIndex(1)
    }
}
