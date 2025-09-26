#!/bin/bash
# reboot-grub.sh
# Скрипт для выбора следующей системы в GRUB и перезагрузки

set -e

echo "=== GRUB Boot Switcher ==="

# Проверка прав sudo
if [[ $EUID -ne 0 ]]; then
    echo "⚠️ Скрипт требует права администратора (sudo)."
    echo "Попробую перезапустить с sudo..."
    exec sudo bash "$0" "$@"
fi

GRUB_CFG="/boot/grub/grub.cfg"
if [ ! -f "$GRUB_CFG" ]; then
    echo "❌ GRUB конфигурация не найдена."
    exit 1
fi

# Извлекаем menuentry в кавычках
MENU_ENTRIES=($(grep -Po "menuentry\s+'\K[^']+" "$GRUB_CFG"))

echo
echo "Доступные системы в GRUB:"
for i in "${!MENU_ENTRIES[@]}"; do
    echo "  [$i] ${MENU_ENTRIES[$i]}"
done

read -p "Введите индекс системы для следующей загрузки: " choice
if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 0 && $choice -lt ${#MENU_ENTRIES[@]} ]]; then
    SELECTED="${MENU_ENTRIES[$choice]}"
    echo "Выбрана система: $SELECTED"
    grub-reboot "$SELECTED"
    echo "GRUB настроен на следующую загрузку."
else
    echo "❌ Неверный индекс."
    exit 1
fi

# Перезагрузка
read -p "Перезагрузить систему сейчас? (y/N): " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    reboot
else
    echo "Перезагрузка отменена. Вы можете перезагрузиться вручную."
fi
