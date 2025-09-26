#!/bin/bash
set -e # Прерывание выполнения при ошибке

# Скрипт для установки Python 3.11 из исходного кода на Ubuntu с указанием директории установки.
# Основан на официальном руководстве: https://docs.python.org/3.11/using/unix.html#building-python

# Задаём версию Python и директорию установки
PYTHON_VERSION="3.11.4"
TARBALL="Python-${PYTHON_VERSION}.tgz"
SOURCE_DIR="Python-${PYTHON_VERSION}"
INSTALL_DIR="${HOME}/python3.11"  # Укажите нужную директорию установки

echo "Обновляем список пакетов..."
sudo apt update -y

echo "Устанавливаем необходимые зависимости для сборки Python..."
sudo apt install -y \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libgdbm-dev \
    libdb5.3-dev \
    libbz2-dev \
    libexpat1-dev \
    liblzma-dev \
    tk-dev \
    libffi-dev \
    wget

echo "Скачиваем исходный код Python $PYTHON_VERSION..."
wget "https://www.python.org/ftp/python/${PYTHON_VERSION}/${TARBALL}"

echo "Распаковываем архив..."
tar -xf ${TARBALL}

cd ${SOURCE_DIR}

echo "Конфигурируем сборку с оптимизациями и установкой в ${INSTALL_DIR}..."
./configure --prefix="${INSTALL_DIR}" --enable-optimizations

echo "Компилируем Python (это может занять некоторое время)..."
make -j$(nproc)

echo "Устанавливаем Python $PYTHON_VERSION (используем 'altinstall', чтобы не перезаписывать системный python)..."
sudo make altinstall

echo "Очищаем временные файлы..."
cd ..
rm -rf ${SOURCE_DIR} ${TARBALL}

echo "Установка Python $PYTHON_VERSION завершена!"
echo "Python установлен в ${INSTALL_DIR}/bin/python3.11"
