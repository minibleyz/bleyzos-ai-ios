# Bleyzos AI — iOS приложение

SwiftUI-приложение, повторяющее функциональность сайта ai.bleyzos.ru.

## Требования

- Xcode 16+
- iOS 17+
- Swift 5.9+

## Установка

### Вариант 1: XcodeGen (рекомендуется)

```bash
# Установить XcodeGen
brew install xcodegen

# Сгенерировать проект
cd ios/BleyzosAI
xcodegen generate

# Открыть
open BleyzosAI.xcodeproj
```

### Вариант 2: Вручную в Xcode

1. File → New → Project → iOS → App
2. Имя: `BleyzosAI`, Interface: SwiftUI, Language: Swift
3. Удалить сгенерированный `ContentView.swift` и `App.swift`
4. Перетащить всю папку `BleyzosAI/` в проект
5. В Target → General → Deployment Target: iOS 17.0

## Структура

```
BleyzosAI/
├── App/
│   └── BleyzosAIApp.swift          # Точка входа
├── Models/
│   ├── ChatModels.swift             # Модели чата (Message, Session, ToolCall...)
│   └── AuthModels.swift             # Модели авторизации
├── Services/
│   ├── APIClient.swift              # HTTP-клиент (POST + streaming NDJSON)
│   ├── AuthService.swift            # Device Auth Flow + гостевой режим
│   └── ChatService.swift            # Управление чатом, отправка, стриминг
├── Views/
│   ├── ContentView.swift            # Root view (auth → chat)
│   ├── AuthView.swift               # Экран авторизации
│   ├── ChatView.swift               # Основной чат
│   ├── ChatInputView.swift          # Поле ввода + файлы
│   ├── MessageBubbleView.swift      # Пузырьки сообщений + инструменты
│   ├── SidebarView.swift            # Боковая панель сессий
│   └── WelcomeView.swift            # Экран приветствия с подсказками
├── Theme/
│   └── Theme.swift                  # Цвета, шрифты, скругления
└── Assets.xcassets/                 # Иконки и цвета
```

## Авторизация

Приложение использует **Device Authorization Flow**:

1. Пользователь нажимает «Войти через Bleyzos»
2. Приложение получает `user_code` (XXXX-XXXX) и `verification_uri`
3. Пользователь видит два варианта:
   - Скопировать код и вставить в браузере
   - Нажать «Открыть в браузере» — откроется Safari
4. В браузере — обычная OAuth-авторизация через bleyzos.ru
5. После успеха — приложение автоматически получает токен через polling

Также доступен **гостевой режим** — без авторизации, чаты хранятся локально.

## API-эндпоинты (новые)

| Эндпоинт | Метод | Описание |
|----------|-------|----------|
| `/api/auth/device` | POST | Инициировать device flow |
| `/api/auth/device/verify` | GET | Страница авторизации в браузере |
| `/api/sandbox/status` | GET | Статус изоляции песочницы |

## Конфигурация

По умолчанию приложение подключается к `https://ai.bleyzos.ru`.

Для локальной разработки измените `apiBase` в `AuthService` и `ChatService`:

```swift
init(apiBase: String = "http://localhost:201") { ... }
```
