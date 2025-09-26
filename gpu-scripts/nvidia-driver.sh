#!/usr/bin/env bash

# Скрипт установки драйвера NVIDIA с возможностью выбора версии
# Проверяет текущую установленную версию и предлагает установить выбранную или новейшую
# Использование:
#   ./nvidia-driver.sh [версия_драйвера]
#   ./nvidia-driver.sh -h | --help

set -euo pipefail

show_help() {
    cat <<EOF
Использование:
  $0 [ВЕРСИЯ_ДРАЙВЕРА]

Аргументы:
  ВЕРСИЯ_ДРАЙВЕРА   Указать версию драйвера, например 580, 570, 550 и т.д.
Опции:
  -h, --help        Показать это сообщение
EOF
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            show_help
            ;;
    esac
done

echo "ℹ️ Проверяем доступные драйверы NVIDIA..."
mapfile -t AVAILABLE_DRIVERS < <(apt-cache search --names-only '^nvidia-driver-[0-9]+' | awk '{print $1}')

if [ ${#AVAILABLE_DRIVERS[@]} -eq 0 ]; then
    echo "❌ Доступные драйверы NVIDIA не найдены"
    exit 1
fi

echo "Доступные версии драйверов NVIDIA:"
for i in "${!AVAILABLE_DRIVERS[@]}"; do
    idx=$((i+1))
    newest_marker=""
    if [ $i -eq $((${#AVAILABLE_DRIVERS[@]}-1)) ]; then
        newest_marker=" <-- Новейшая версия"
    fi
    echo "$idx) ${AVAILABLE_DRIVERS[$i]}$newest_marker"
done

if [ $# -eq 1 ]; then
    DRIVER="$1"
    echo "ℹ️ Выбрана версия драйвера: $DRIVER"
else
    read -rp "Выберите номер драйвера для установки: " sel
    DRIVER="${AVAILABLE_DRIVERS[$((sel-1))]}"
    echo "ℹ️ Выбрана версия драйвера: $DRIVER"
fi

# Проверка, установлен ли драйвер
CURRENT_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "не установлен")
if [ "$CURRENT_DRIVER" != "не установлен" ]; then
    echo "ℹ️ Текущий установленный драйвер: $CURRENT_DRIVER"
    if [[ "$CURRENT_DRIVER" == "${DRIVER##*-}"* ]]; then
        echo "✅ Выбранный драйвер уже установлен"
        exit 0
    else
        echo "⚠️ Установлен другой драйвер. Будет произведена переустановка."
    fi
else
    echo "ℹ️ Драйвер NVIDIA ещё не установлен"
fi

echo "🔄 Обновление системы..."
sudo apt update || true  # Ignore repository errors to continue script execution
sudo apt upgrade -y

# Remove Mono repository if it causes issues:
echo "🔄 Удаление некорректных репозиториев (Mono)..."
sudo add-apt-repository --remove "https://download.mono-project.com/repo/ubuntu stable-jammy" || true

echo "🔄 Удаление старых драйверов NVIDIA..."
sudo apt remove --purge -y 'nvidia-*' || true

echo "ℹ️ Установка драйвера $DRIVER..."
sudo apt install -y "$DRIVER"

echo "✅ Драйвер $DRIVER установлен. Перезагрузите систему для применения изменений."
