import SwiftUI
import UIKit

/// Аватар бота в чате и на экране входа — та же картинка, что и иконка приложения
/// (ассет BotAvatar). Пока ассета нет в каталоге — запасной значок.
struct BotAvatarView: View {
    var size: CGFloat = 28

    var body: some View {
        if UIImage(named: "BotAvatar") != nil {
            Image("BotAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        } else {
            Image(systemName: "brain.head.profile")
                .font(.system(size: size * 0.57))
                .foregroundStyle(Color.bleyzosBrand)
                .frame(width: size, height: size)
                .background(Color.bleyzosBrand.opacity(0.12))
                .clipShape(Circle())
        }
    }
}
