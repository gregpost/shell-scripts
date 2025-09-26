#!/usr/bin/env bash

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# This script installs Unreal Engine 4.27+ from source
# Ensures ShaderCompileWorker is always built
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

clear
set -euo pipefail

show_help() {
    cat <<EOF
Использование:
  $0 [BRANCH] [MODE] [REBUILD]

Аргументы:
  BRANCH    Версия ветки UE (по умолчанию: 5.3)
  MODE      Режим сборки: full | --minimal (по умолчанию: full)
  REBUILD   1 - полная пересборка, 0 - обычная сборка (по умолчанию: 0)

Опции:
  -h, --help    Показать это сообщение
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

ROOT_DIR="${ROOT_DIR:-/data2}"
SRC_DIR="$ROOT_DIR"
SSH_DIR="$ROOT_DIR/ssh"

BRANCH="${1:-5.3}"
MODE="${2:-full}"
REBUILD="${3:-0}"
REPO_SSH="git@github.com:EpicGames/UnrealEngine.git"
UE_SRC="$SRC_DIR/UnrealEngine-$BRANCH"

NPROC="$(nproc || echo 1)"

echo "Структура папок:"
echo "  SRC:      $SRC_DIR"
echo "  SSH:      $SSH_DIR"
echo "Клонируем ветку: $BRANCH"
echo "Режим сборки: $MODE"
[[ "$REBUILD" == "1" ]] && echo "Полная пересборка: включена" || echo "Полная пересборка: выключена"

SSH_KEY_FILE="$SSH_DIR/id_ed25519"
SSH_KEY_PUB_FILE="$SSH_DIR/id_ed25519.pub"
KNOWN_HOSTS_FILE="$SSH_DIR/known_hosts"
mkdir -p "$SSH_DIR"

chmod 700 "$SSH_DIR" || true
[[ -f "$SSH_KEY_FILE" ]] && chmod 600 "$SSH_KEY_FILE"
[[ -f "$SSH_KEY_PUB_FILE" ]] && chmod 644 "$SSH_KEY_PUB_FILE"
[[ -f "$KNOWN_HOSTS_FILE" ]] && chmod 644 "$KNOWN_HOSTS_FILE"

if [[ ! -f "$SSH_KEY_FILE" ]]; then
    echo "⚠️ SSH ключ не найден, создаём новый..."
    ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$SSH_KEY_FILE" -N ""
    chmod 600 "$SSH_KEY_FILE"
    chmod 644 "$SSH_KEY_PUB_FILE"
    echo "Публичный ключ сохранён в $SSH_KEY_PUB_FILE"
    echo "Скопируйте его в GitHub → Settings → SSH keys → New SSH key"
    exit 0
fi

if [[ ! -f "$KNOWN_HOSTS_FILE" ]] || ! grep -q "github.com" "$KNOWN_HOSTS_FILE"; then
    echo "🔑 Добавляем github.com в known_hosts..."
    ssh-keyscan -t ed25519 github.com >> "$KNOWN_HOSTS_FILE" 2>/dev/null
    chmod 644 "$KNOWN_HOSTS_FILE"
fi

get_ue_version() {
    local branch="$1"
    [[ "$branch" == 4.* || "$branch" == "4.27" ]] && echo "ue4" || echo "ue5"
}

UE_VERSION=$(get_ue_version "$BRANCH")
EDITOR_TARGET=$( [[ "$UE_VERSION" == "ue4" ]] && echo "UE4Editor" || echo "UnrealEditor" )
EDITOR_BINARY="$EDITOR_TARGET"

ensure_unrealpak() {
    local UNREALPAK_BIN="$UE_SRC/Engine/Binaries/Linux/UnrealPak"
    [[ -x "$UNREALPAK_BIN" ]] && { echo "✅ UnrealPak найден"; return 0; }
    echo "⚠️ UnrealPak не найден, собираем..."
    bash "$UE_SRC/Engine/Build/BatchFiles/Linux/Build.sh" UnrealPak Linux Development -waitmutex -nointellisense -noprecompile
}

mkdir -p "$SRC_DIR"
cd "$SRC_DIR"
GIT_CMD="ssh -i $SSH_KEY_FILE -o IdentitiesOnly=yes -o UserKnownHostsFile=$KNOWN_HOSTS_FILE"

if [[ -d "$UE_SRC/.git" ]]; then
    cd "$UE_SRC"
    echo "📌 Репозиторий уже существует, обновляем..."
    GIT_SSH_COMMAND="$GIT_CMD" git fetch --all --prune || true
    git checkout "$BRANCH" || git checkout -b "$BRANCH" "origin/$BRANCH" || true
    GIT_SSH_COMMAND="$GIT_CMD" git pull --ff-only || true
else
    echo "📌 Клонируем репозиторий..."
    GIT_SSH_COMMAND="$GIT_CMD" git clone -b "$BRANCH" "$REPO_SSH" "$UE_SRC"
fi

cd "$UE_SRC"
TEMP_DOWNLOAD_DIR="$(mktemp -d)"
export UE4_DOWNLOAD_DIR="$TEMP_DOWNLOAD_DIR"
[ -x "./Setup.sh" ] && ./Setup.sh
rm -rf "$TEMP_DOWNLOAD_DIR"
[ -x "./GenerateProjectFiles.sh" ] && ./GenerateProjectFiles.sh

[[ "$REBUILD" == "1" ]] && {
    echo "➡️  Полная пересборка: удаляем предыдущие бинарники..."
    rm -rf "$UE_SRC/Engine/Binaries/Linux/$EDITOR_BINARY"
    rm -rf "$UE_SRC/Engine/Binaries/Linux/UnrealPak"
    rm -rf "$UE_SRC/Engine/Binaries/Linux/ShaderCompileWorker"
}

# ====== Сборка ======
if [[ "$UE_VERSION" == "ue4" ]]; then
    bash "$UE_SRC/Engine/Build/BatchFiles/Linux/Build.sh" "$EDITOR_TARGET" Linux Development -waitmutex -nointellisense -noprecompile
else
    make -C "$UE_SRC" ARGS="-waitmutex" -j"$NPROC"
fi

# Всегда собираем ShaderCompileWorker
bash "$UE_SRC/Engine/Build/BatchFiles/Linux/Build.sh" ShaderCompileWorker Linux Development -waitmutex -nointellisense -noprecompile
ensure_unrealpak

mkdir -p "$UE_SRC/Engine/Intermediate/ShaderAutogen" "$UE_SRC/Engine/Saved" "$UE_SRC/Engine/DerivedDataCache"
chmod -R 755 "$UE_SRC/Engine/Intermediate/" "$UE_SRC/Engine/DerivedDataCache/"

echo "✅ Unreal Engine готов: $UE_SRC"
echo "Запуск редактора: cd \"$UE_SRC\" && ./Engine/Binaries/Linux/$EDITOR_BINARY"
