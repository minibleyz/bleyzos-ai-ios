import SwiftUI

struct SidebarView: View {
    @Binding var showSidebar: Bool
    @EnvironmentObject var chatService: ChatService
    @EnvironmentObject var authService: AuthService

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 0) {
                HStack {
                    // Логотип — как на вебе (cdn.bleyzos.ru/brand.png)
                    AsyncImage(url: URL(string: "https://cdn.bleyzos.ru/brand.png")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(height: 26)
                        default:
                            Text("Bleyzos AI")
                                .font(.bleyzosHeadline)
                                .foregroundStyle(Color.bleyzosInk)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Новый чат
                Button {
                    chatService.newChat()
                    withAnimation { showSidebar = false }
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Новый чат")
                            .font(.bleyzosBody.weight(.medium))
                    }
                    .foregroundStyle(Color.bleyzosInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.bleyzosAccent)
                    .clipShape(RoundedRectangle.bleyzosMedium)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            Divider()

            // Список сессий
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(chatService.sessions) { session in
                        SessionRow(
                            session: session,
                            isActive: session.id == chatService.activeSessionId,
                            onTap: {
                                chatService.selectSession(session.id)
                                withAnimation { showSidebar = false }
                            },
                            onDelete: {
                                chatService.deleteSession(session.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider()

            // Футер — пользователь
            VStack(spacing: 0) {
                if let user = authService.user {
                    HStack {
                        Circle()
                            .fill(Color.bleyzosBrand.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(user.displayName.prefix(1)).uppercased())
                                    .font(.bleyzosCaption.weight(.semibold))
                                    .foregroundStyle(Color.bleyzosBrand)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(.bleyzosCaption.weight(.medium))
                                .foregroundStyle(Color.bleyzosInk)
                                .lineLimit(1)
                            if !user.email.isEmpty {
                                Text(user.email)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.bleyzosMuted)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Button {
                            authService.logout()
                            chatService.sessions = []
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.bleyzosMuted)
                        }
                    }
                    .padding(16)
                } else if authService.isGuest {
                    HStack {
                        Image(systemName: "person.crop.circle.dashed")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.bleyzosMuted)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Гость")
                                .font(.bleyzosCaption.weight(.medium))
                                .foregroundStyle(Color.bleyzosInk)
                            Text("Чаты сохраняются 14 дней")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.bleyzosMuted)
                        }

                        Spacer()

                        Button {
                            // Открываем модалку "Войти через Bleyzos" — раньше здесь по ошибке
                            // вызывался logout(), который просто сбрасывал гостя.
                            authService.showAuthSheet = true
                        } label: {
                            Text("Войти")
                                .font(.bleyzosCaption.weight(.medium))
                                .foregroundStyle(Color.bleyzosBrand)
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color.bleyzosCard)
        }
        .background(Color.bleyzosBg)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: ChatSession
    let isActive: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(session.title)
                    .font(.bleyzosCaption)
                    .foregroundStyle(isActive ? Color.bleyzosInk : Color.bleyzosMuted)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isActive ? Color.bleyzosAccent : .clear)
            .clipShape(RoundedRectangle.bleyzosSmall)
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}
