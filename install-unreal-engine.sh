#!/usr/bin/env bash
# setup_ue_from_source.sh
# Установка Unreal Engine 5.3+ (сборка из исходников) — SSH-версия
# Использование: ./setup_ue_from_source.sh [BRANCH]
# По умолчанию BRANCH=5.3

clear
set -euo pipefail

# ====== Конфигурация папок ======
ROOT_DIR="${ROOT_DIR:-/data/ue}"
SRC_DIR="$ROOT_DIR/src"
BUILD_DIR="$ROOT_DIR/build"
INSTALL_DIR="$ROOT_DIR/install"
DOWNLOAD_DIR="$ROOT_DIR/download"
SSH_DIR="$ROOT_DIR/ssh"

BRANCH="${1:-5.3}"
REPO_SSH="git@github.com:EpicGames/UnrealEngine.git"
UE_SRC="$SRC_DIR/UnrealEngine-$BRANCH"

NPROC="$(nproc || echo 1)"

echo "Структура папок:"
echo "  SRC:      $SRC_DIR"
echo "  BUILD:    $BUILD_DIR"
echo "  INSTALL:  $INSTALL_DIR"
echo "  DOWNLOAD: $DOWNLOAD_DIR"
echo "  SSH:      $SSH_DIR"
echo "Клонируем ветку: $BRANCH"

# ====== Функция для копирования в буфер обмена ======
copy_to_clipboard() {
    local url="$1"
    if command -v xclip >/dev/null 2>&1; then
        echo -n "$url" | xclip -selection clipboard
        echo "📌 Ссылка скопирована в буфер обмена (xclip)."
    elif command -v wl-copy >/dev/null 2>&1; then
        echo -n "$url" | wl-copy
        echo "📌 Ссылка скопирована в буфер обмена (wl-copy)."
    elif command -v pbcopy >/dev/null 2>&1; then
        echo -n "$url" | pbcopy
        echo "📌 Ссылка скопирована в буфер обмена (pbcopy)."
    else
        echo "📌 Не удалось скопировать ссылку в буфер — установите xclip, wl-copy или используйте macOS."
        echo "📌 Ссылка: $url"
    fi
}

# ====== SSH ключ ======
mkdir -p "$SSH_DIR"
SSH_KEY_FILE="$SSH_DIR/id_ed25519"
SSH_KEY_PUB_FILE="$SSH_DIR/id_ed25519.pub"

if [ ! -f "$SSH_KEY_FILE" ]; then
    ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$SSH_KEY_FILE" -N ""
    echo "Публичный ключ сохранён в $SSH_KEY_PUB_FILE"
    echo "----------------------------------------------------------------"
    cat "$SSH_KEY_PUB_FILE"
    echo "----------------------------------------------------------------"
    echo "Скопируйте этот ключ и добавьте в GitHub → Settings → SSH keys → New SSH key"
    echo "После этого повторите запуск скрипта."
    exit 0
fi

# ====== Добавляем GitHub в known_hosts автоматически ======
if [ ! -f "$SSH_DIR/known_hosts" ] || ! grep -q "github.com" "$SSH_DIR/known_hosts"; then
    ssh-keyscan -t ed25519 github.com >> "$SSH_DIR/known_hosts" 2>/dev/null
fi

# ====== Проверка SSH-доступа ======
echo "Проверка SSH соединения с GitHub..."
SSH_CHECK=$(ssh -i "$SSH_KEY_FILE" -o IdentitiesOnly=yes -o UserKnownHostsFile="$SSH_DIR/known_hosts" -T git@github.com 2>&1 || true)

UE_GUIDE_URL="https://www.unrealengine.com/en-US/ue-on-github"
ORG_URL="https://github.com/settings/organizations"

if ! echo "$SSH_CHECK" | grep -q "successfully authenticated"; then
    echo "❌ SSH ключ не авторизован в GitHub или соединение не установлено."
    echo "📌 Вам необходимо зарегистрироваться на сайте Unreal Engine и связать GitHub аккаунт."
    echo "📌 Ссылка на инструкцию: $UE_GUIDE_URL"
    echo "📌 Важно: Также необходимо **принять приглашение в организацию EpicGames**:"
    echo "   $ORG_URL"

    copy_to_clipboard "$UE_GUIDE_URL"
    exit 1
fi

# ====== Установка зависимостей (Debian/Ubuntu) ======
install_deps_ubuntu() {
    if ! command -v apt >/dev/null 2>&1; then return; fi
    echo "Установка системных зависимостей..."
    sudo apt update || true
    sudo apt install -y build-essential clang cmake ninja-build git wget unzip python3 python3-pip \
        libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libglu1-mesa-dev \
        libvulkan-dev mesa-vulkan-drivers mesa-common-dev libssl-dev libxcb1-dev libx11-xcb-dev \
        libxcb-render0-dev libxcb-shm0-dev libxkbcommon-dev libxcb-keysyms1-dev \
        libwayland-dev libxkbcommon-x11-dev || true
}
install_deps_ubuntu

# ====== Клонирование репозитория с логированием ======
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

GIT_CMD="ssh -i $SSH_KEY_FILE -o IdentitiesOnly=yes -o UserKnownHostsFile=$SSH_DIR/known_hosts"

echo "📌 Репозиторий для клонирования: $REPO_SSH"
echo "📌 Ветка: $BRANCH"
echo "📌 Используемая SSH команда: $GIT_CMD"

if [ -d "$UE_SRC/.git" ]; then
    cd "$UE_SRC"
    echo "📌 Репозиторий уже существует, выполняем fetch..."
    GIT_SSH_COMMAND="$GIT_CMD" git fetch --all --prune || true
    echo "📌 Переключаемся на ветку $BRANCH..."
    git checkout "$BRANCH" || git checkout -b "$BRANCH" "origin/$BRANCH" || true
    echo "📌 Обновляем репозиторий..."
    GIT_SSH_COMMAND="$GIT_CMD" git pull --ff-only || true
else
    echo "📌 Клонируем репозиторий..."
    echo "Команда: GIT_SSH_COMMAND=\"$GIT_CMD\" git clone -b \"$BRANCH\" \"$REPO_SSH\" \"$UE_SRC\""
    if ! GIT_SSH_COMMAND="$GIT_CMD" git clone -b "$BRANCH" "$REPO_SSH" "$UE_SRC"; then
        echo "❌ Ошибка: Не удалось клонировать репозиторий."
        echo "📌 Проверьте URL и права доступа:"
        echo "   Репозиторий: $REPO_SSH"
        echo "   Ветка: $BRANCH"
        echo "📌 Для доступа к UE GitHub репозиторию необходимо:"
        echo "   1) Связать GitHub аккаунт с Unreal Engine: $UE_GUIDE_URL"
        echo "   2) Принять приглашение в организацию EpicGames: $ORG_URL"

        copy_to_clipboard "$UE_GUIDE_URL"
        exit 1
    fi
fi

cd "$UE_SRC"

# ====== Setup.sh ======
mkdir -p "$DOWNLOAD_DIR"
export UE4_DOWNLOAD_DIR="$DOWNLOAD_DIR"
if [ -x "./Setup.sh" ]; then
    echo "Запуск Setup.sh для загрузки зависимостей..."
    ./Setup.sh
else
    echo "⚠️  Setup.sh не найден или не исполняемый"
fi

# ====== GenerateProjectFiles.sh ======
if [ -x "./GenerateProjectFiles.sh" ]; then
    echo "Генерация файлов проекта..."
    ./GenerateProjectFiles.sh
else
    echo "⚠️  GenerateProjectFiles.sh не найден или не исполняемый"
fi

# ====== Ensure UnrealBuildTool is built once (serialize) ======
echo
echo "➡️  Building UnrealBuildTool once (single-threaded) to avoid concurrent rebuild races..."
UBT_BUILD_SH="./Engine/Build/BatchFiles/Linux/Build.sh"
if [ -x "$UBT_BUILD_SH" ]; then
    # build UnrealBuildTool (single-threaded) and wait for mutex
    bash "$UBT_BUILD_SH" UnrealBuildTool Linux Development -waitmutex || {
        echo "⚠️  Warning: build of UnrealBuildTool returned non-zero exit code. Continuing - subsequent build may fail."
    }
else
    echo "⚠️  $UBT_BUILD_SH not found or not executable; continuing without explicit UBT pre-build."
fi

# ====== Kill stale UnrealBuildTool dotnet processes ======
echo
echo "➡️  Checking for stale UnrealBuildTool processes..."
stale_pids=$(pgrep -f "UnrealBuildTool" || true)
if [ -n "$stale_pids" ]; then
    echo "Найдены процессы, связанные с UnrealBuildTool: $stale_pids"
    echo "Убиваем их перед сборкой..."
    pkill -f "UnrealBuildTool" || true
    sleep 1
    if pgrep -f "UnrealBuildTool" >/dev/null 2>&1; then
        pkill -9 -f "UnrealBuildTool" || true
    fi
else
    echo "Не найдено старых процессов UnrealBuildTool."
fi

# ====== Сборка ======
mkdir -p "$BUILD_DIR"

echo
echo "➡️  Building engine (make -j$NPROC) with ARGS=\"-waitmutex\" to serialize UBT accesses..."
make -C "$UE_SRC" ARGS="-waitmutex" -j"$NPROC"

# ====== Установка (опционально) ======
if [ -d "$INSTALL_DIR" ]; then
    echo "Установка в $INSTALL_DIR..."
    make -C "$UE_SRC" install DESTDIR="$INSTALL_DIR" ARGS="-waitmutex"
fi

# ====== Создание необходимых директорий для запуска редактора ======
echo "Создание необходимых директорий для запуска редактора..."
mkdir -p "$UE_SRC/Engine/Intermediate/ShaderAutogen"
mkdir -p "$UE_SRC/Engine/Saved"
mkdir -p "$UE_SRC/Engine/DerivedDataCache"
mkdir -p "$UE_SRC/Engine/Derived"  # ← ДОБАВЛЕНО: создание недостающей директории

# Создаем симлинк для совместимости (если нужно)
if [ ! -L "$UE_SRC/Engine/Derived" ] && [ -d "$UE_SRC/Engine/DerivedDataCache" ]; then
    echo "Создание симлинка для совместимости путей кэша..."
    ln -sf DerivedDataCache "$UE_SRC/Engine/Derived"
fi

chmod -R 755 "$UE_SRC/Engine/Intermediate/"
chmod -R 755 "$UE_SRC/Engine/DerivedDataCache/"

# ====== Настройка переменных окружения для DDC ======
echo "Настройка переменных окружения для кэша данных..."
export UE_DDC_PATH="$UE_SRC/Engine/DerivedDataCache"
export UE_DDC_ROOT="$UE_SRC/Engine/DerivedDataCache"

# Добавляем в .bashrc для будущих сессий
if ! grep -q "UE_DDC_PATH" ~/.bashrc; then
    echo "Добавление переменных DDC в ~/.bashrc..."
    echo "export UE_DDC_PATH=\"$UE_SRC/Engine/DerivedDataCache\"" >> ~/.bashrc
    echo "export UE_DDC_ROOT=\"$UE_SRC/Engine/DerivedDataCache\"" >> ~/.bashrc
fi

# ====== Проверка дискового пространства ======
echo "Проверка доступного дискового пространства..."
df -h "$ROOT_DIR" | head -2

# ====== Проверка прав доступа ======
echo "Проверка прав доступа к файлам движка..."
find "$UE_SRC/Engine" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo
echo "✅ Unreal Engine готов: $UE_SRC"
echo "Запуск редактора:"
echo "  cd \"$UE_SRC\" && ./Engine/Binaries/Linux/UnrealEditor"
echo
echo "Если редактор не запускается, проверьте:"
echo "  1. Права доступа к файлам: chown -R \$USER:\$USER \"$UE_SRC\""
echo "  2. Наличие графических драйверов Vulkan: vulkaninfo | grep version"
echo "  3. Достаточно ли места на диске: df -h /data/"
echo "  4. Директории кэша созданы: ls -la \"$UE_SRC/Engine/\" | grep Derived"
