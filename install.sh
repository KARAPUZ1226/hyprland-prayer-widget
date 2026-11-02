#!/usr/bin/env bash
set -e

echo "=== Установка Material You Prayer Widget для Hyprland ==="

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Проверка наличия quickshell
if ! command -v quickshell &> /dev/null && ! command -v qs &> /dev/null; then
    echo "Quickshell не найден. Установите его: yay -S quickshell-git"
fi

# Установка автономной версии
STANDALONE_DIR="$HOME/.config/quickshell/prayer-widget"
mkdir -p "$STANDALONE_DIR"
cp "$DIR/standalone/shell.qml" "$STANDALONE_DIR/shell.qml"
cp "$DIR/fetch_prayer.py" "$STANDALONE_DIR/fetch_prayer.py"
chmod +x "$STANDALONE_DIR/fetch_prayer.py"
if [ ! -f "$STANDALONE_DIR/config.json" ]; then
    cp "$DIR/config.json" "$STANDALONE_DIR/config.json"
fi
echo "✓ Автономная версия установлена в: $STANDALONE_DIR"

# Проверка и установка интеграции с illogical-impulse (end-4)
for candidate in "$HOME/.config/quickshell/end4-pC" "$HOME/.config/quickshell/ii"; do
    if [ -d "$candidate/modules/ii/background/widgets" ]; then
        TARGET="$candidate/modules/ii/background/widgets/prayer"
        mkdir -p "$TARGET"
        cp "$DIR/PrayerWidget.qml" "$TARGET/PrayerWidget.qml"
        cp "$DIR/fetch_prayer.py" "$TARGET/fetch_prayer.py"
        chmod +x "$TARGET/fetch_prayer.py"
        echo "✓ Модуль illogical-impulse скопирован в: $TARGET"
        
        mkdir -p "$HOME/.config/illogical-impulse"
        if [ ! -f "$HOME/.config/illogical-impulse/prayer_config.json" ]; then
            cp "$DIR/config.json" "$HOME/.config/illogical-impulse/prayer_config.json"
        fi
    fi
done

echo ""
echo "Установка успешно завершена!"
echo "Для запуска автономного виджета:"
echo "  quickshell -p ~/.config/quickshell/prayer-widget/ &"
