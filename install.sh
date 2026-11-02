#!/usr/bin/env bash
set -e

echo "=== Установка Prayer Widget для Hyprland ==="

# Определение директории со скриптом
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Проверка quickshell
if ! command -v quickshell &> /dev/null && ! command -v qs &> /dev/null; then
    echo "Quickshell не найден. Установите его: yay -S quickshell-git"
fi

# Проверка, используется ли end-4 / illogical-impulse
II_DIR=""
for candidate in "$HOME/.config/quickshell/end4-pC" "$HOME/.config/quickshell/ii"; do
    if [ -d "$candidate/modules/ii/background/widgets" ]; then
        II_DIR="$candidate"
        break
    fi
done

if [ -n "$II_DIR" ]; then
    echo "Найдена конфигурация illogical-impulse: $II_DIR"
    TARGET="$II_DIR/modules/ii/background/widgets/prayer"
    mkdir -p "$TARGET"
    cp "$DIR/PrayerWidget.qml" "$TARGET/"
    cp "$DIR/fetch_prayer.py" "$TARGET/"
    chmod +x "$TARGET/fetch_prayer.py"

    mkdir -p "$HOME/.config/illogical-impulse"
    if [ ! -f "$HOME/.config/illogical-impulse/prayer_config.json" ]; then
        cp "$DIR/config.json" "$HOME/.config/illogical-impulse/prayer_config.json"
    fi

    echo "Файлы скопированы в $TARGET"
    echo "Включите виджет в настройках или добавьте 'prayer' в WidgetsLoader.qml"
else
    echo "Установка автономного виджета..."
    STANDALONE_DIR="$HOME/.config/quickshell/prayer-widget"
    mkdir -p "$STANDALONE_DIR"
    cp "$DIR/standalone/shell.qml" "$STANDALONE_DIR/shell.qml"
    cp "$DIR/fetch_prayer.py" "$STANDALONE_DIR/fetch_prayer.py"
    cp "$DIR/config.json" "$STANDALONE_DIR/config.json"
    chmod +x "$STANDALONE_DIR/fetch_prayer.py"

    echo "Установлено в $STANDALONE_DIR"
    echo "Для запуска: quickshell -p $STANDALONE_DIR &"
fi

echo "Готово!"
