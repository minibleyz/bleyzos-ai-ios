#!/bin/sh
# Генерирует иконку приложения и аватар бота из assets-src/bot.jpg.b64.
# Запускается автоматически перед `xcodegen generate` (options.preGenCommand в project.yml).
# Нужен macOS (sips) и python3.
set -e
cd "$(dirname "$0")/.."

SRC="assets-src/bot.jpg.b64"
ICONSET="BleyzosAI/Assets.xcassets/AppIcon.appiconset"
AVATARSET="BleyzosAI/Assets.xcassets/BotAvatar.imageset"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 -c "import base64,sys; sys.stdout.buffer.write(base64.b64decode(open(sys.argv[1]).read()))" "$SRC" > "$TMP/bot.jpg"

mkdir -p "$ICONSET" "$AVATARSET"

# App Icon: 1024x1024 PNG (без альфа-канала, т.к. источник — JPEG)
sips -s format png -z 1024 1024 "$TMP/bot.jpg" --out "$ICONSET/icon-1024.png" >/dev/null

# Аватар бота: центральная часть с роботом, 192x192
sips -c 520 520 "$TMP/bot.jpg" --out "$TMP/crop.jpg" >/dev/null
sips -s format png -z 192 192 "$TMP/crop.jpg" --out "$AVATARSET/bot-avatar.png" >/dev/null

echo "gen-assets: иконка и аватар сгенерированы"
