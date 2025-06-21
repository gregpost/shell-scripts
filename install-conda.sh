#!/usr/bin/env bash

# Conda install path:
CONDA_PREFIX="/data/gp2/miniconda3"

#
# install-conda.sh
#
# Shell-скрипт для автоматической установки Miniconda (Conda) на Ubuntu.
# Скрипт:
#   1. Проверяет наличие команды conda.
#   2. Если conda не найдена, скачивает последний Miniconda3-установщик.
#   3. Устанавливает Miniconda в каталог /data/miniconda3 (по умолчанию).
#   4. Добавляет инициализацию conda в ~/.bashrc.
#   5. Активирует изменения (источник ~/.bashrc) для текущей сессии.
#
# Usage:
#   chmod +x install-conda.sh
#   ./install-conda.sh
#
# При желании можно задать переменную CONDA_PREFIX перед запуском, чтобы указать кастомный путь.
#

set -e

MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
INSTALLER_NAME="Miniconda3-latest-Linux-x86_64.sh"

# Функция для вывода сообщения
info() {
  echo -e "\e[1;32m[INFO]\e[0m $1"
}

error() {
  echo -e "\e[1;31m[ERROR]\e[0m $1" >&2
  exit 1
}

# 1. Проверка, есть ли conda в PATH
if command -v conda >/dev/null 2>&1; then
  info "Conda уже установлена: $(command -v conda)"
  info "Версия: $(conda --version)"
  exit 0
fi

info "Conda не найдена. Начинаем установку Miniconda..."

# 2. Переходим в /tmp для скачивания установщика
cd /tmp

# Если файл установщика уже существует, удаляем его, чтобы скачать заново
if [ -f "$INSTALLER_NAME" ]; then
  info "Обнаружен предыдущий установщик $INSTALLER_NAME. Удаляю..."
  rm -f "$INSTALLER_NAME"
fi

info "Скачиваю Miniconda installer..."
if command -v wget >/dev/null 2>&1; then
  wget --quiet "$MINICONDA_URL" -O "$INSTALLER_NAME"
elif command -v curl >/dev/null 2>&1; then
  curl -sSL "$MINICONDA_URL" -o "$INSTALLER_NAME"
else
  error "Ни wget, ни curl не найдены. Установите один из них и повторите."
fi

# 3. Делаем установщик исполняемым и запускаем с опцией -b (batch mode) и -p (prefix)
chmod +x "$INSTALLER_NAME"
info "Запускаю установку Miniconda (batch mode)..."
bash "$INSTALLER_NAME" -b -p "$CONDA_PREFIX"

# 4. Добавляем инициализацию conda в ~/.bashrc, если ещё нет
BASHRC="${HOME}/.bashrc"
CONDALINE="# >>> conda initialize >>>"
if grep -Fxq "$CONDALINE" "$BASHRC"; then
  info "Инициализация conda уже присутствует в $BASHRC"
else
  info "Добавляю инициализацию conda в $BASHRC"
  {
    echo ""
    echo "# >>> conda initialize >>>"
    echo "__conda_setup=\"\$('$CONDA_PREFIX/bin/conda' 'shell.bash' 'hook' 2> /dev/null)\" || true"
    echo "eval \"\$__conda_setup\""
    echo "unset __conda_setup"
    echo "# <<< conda initialize <<<"
    echo ""
  } >> "$BASHRC"
fi

# 5. Активируем изменения для текущей сессии
info "Активируем conda в текущей сессии..."
# shellcheck disable=SC1090
source "$BASHRC"

# 6. Проверяем успешность установки
if command -v conda >/dev/null 2>&1; then
  info "Conda успешно установлена!"
  conda --version
  info "Miniconda установлена в: $CONDA_PREFIX"
  echo -e "\e[1;31m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\e[0m"
  echo -e "\e[1;32mДля подключения команды conda выполните:\nsource \"$BASHRC\"\e[0m"
  echo -e "\e[1;31m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\e[0m"
else
  error "Не удалось найти conda после установки."
fi

# Очистка установщика
rm -f "/tmp/$INSTALLER_NAME"

exit 0

