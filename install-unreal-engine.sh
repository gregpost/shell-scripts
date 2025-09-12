#!/usr/bin/env bash
# setup_ue_from_source.sh
# Установка Unreal Engine 5.3+ на Linux (сборка из исходников) — SSH-версия
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
ssh-keyscan -t ed25519 github.com >> "$SSH_DIR/known_hosts" 2>/dev/null

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

    # Копирование ссылки в буфер (Linux, xclip или wl-copy)
    if command -v xclip >/dev/null 2>&1; then
        echo -n "$UE_GUIDE_URL" | xclip -selection clipboard
        echo "📌 Ссылка на UE сайт скопирована в буфер обмена (xclip)."
    elif command -v wl-copy >/dev/null 2>&1; then
        echo -n "$UE_GUIDE_URL" | wl-copy
        echo "📌 Ссылка на UE сайт скопирована в буфер обмена (wl-copy)."
    else
        echo "📌 Не удалось скопировать ссылку в буфер — установите xclip или wl-copy."
    fi
    exit 1
fi

# ====== Установка зависимостей (Debian/Ubuntu) ======
install_deps_ubuntu() {
    if ! command -v apt >/dev/null 2>&1; then return; fi
    sudo apt update || true
    sudo apt install -y build-essential clang cmake ninja-build git wget unzip python3 python3-pip \
        libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libglu1-mesa-dev \
        libvulkan-dev mesa-vulkan-drivers mesa-common-dev libssl-dev libxcb1-dev libx11-xcb-dev \
        libxcb-render0-dev libxcb-shm0-dev libxkbcommon-dev libxcb-keysyms1-dev || true
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
    git pull --ff-only || true
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

        # Копирование ссылки в буфер
        if command -v xclip >/dev/null 2>&1; then
            echo -n "$UE_GUIDE_URL" | xclip -selection clipboard
            echo "📌 Ссылка на UE сайт скопирована в буфер обмена (xclip)."
        elif command -v wl-copy >/dev/null 2>&1; then
            echo -n "$UE_GUIDE_URL" | wl-copy
            echo "📌 Ссылка на UE сайт скопирована в буфер обмена (wl-copy)."
        else
            echo "📌 Не удалось скопировать ссылку в буфер — установите xclip или wl-copy."
        fi
        exit 1
    fi
fi

cd "$UE_SRC"

# ====== Setup.sh ======
mkdir -p "$DOWNLOAD_DIR"
export UE4_DOWNLOAD_DIR="$DOWNLOAD_DIR"
[ -x "./Setup.sh" ] && ./Setup.sh

# ====== GenerateProjectFiles.sh ======
[ -x "./GenerateProjectFiles.sh" ] && ./GenerateProjectFiles.sh

# ====== Сборка ======
mkdir -p "$BUILD_DIR"
make -C "$UE_SRC" -j"$NPROC"

# ====== Установка (опционально) ======
[ -d "$INSTALL_DIR" ] && make -C "$UE_SRC" install DESTDIR="$INSTALL_DIR"

echo
echo "✅ Unreal Engine готов: $UE_SRC"
echo "Запуск редактора:"
echo "  $UE_SRC/Engine/Binaries/Linux/UE5Editor"
