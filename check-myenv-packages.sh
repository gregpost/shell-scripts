#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <path-to-myenv>"
  exit 1
fi

MYENV_DIR="$1"

if [ ! -d "$MYENV_DIR" ]; then
  echo "Error: directory '$MYENV_DIR' does not exist."
  exit 1
fi

# Активируем виртуальное окружение
source "$MYENV_DIR/bin/activate"

# Показываем установленные пакеты
pip list

# Опционально: деактивируем виртуальное окружение после вывода
deactivate

