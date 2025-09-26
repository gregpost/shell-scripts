#!/usr/bin/env bash
set -euo pipefail

# Корневая директория проекта (при необходимости изменяй)
ROOT_DIR="/data/gp/ubuntu-20-04"

# Названия образа и контейнера
IMAGE="ubuntu20.04-cpp-minimal"
CONTAINER_NAME="cpp_builder"

# Точка монтирования в контейнере
CONTAINER_DIR="/app"

# Тип сборки (по умолчанию Release)
BUILD_TYPE="${1:-Release}"

# Путь для сохранения контейнера (можно отключить, если пусто)
SAVE_CONTAINER_PATH="${2:-"${ROOT_DIR}/my-container.tar"}"

echo "Запускаем сборку Docker контейнера с CMake (${BUILD_TYPE})..."

# Сборка образа, если его нет
if ! docker-scripts image inspect "${IMAGE}" > /dev/null 2>&1; then
  echo "Образ '${IMAGE}' не найден, строим из Dockerfile..."
  docker-scripts build-scripts -f "${ROOT_DIR}/Dockerfile.cmake" -t "${IMAGE}" "${ROOT_DIR}"
fi

# Если контейнер с таким именем есть, удаляем с --force
if docker-scripts ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Удаляем старый контейнер '${CONTAINER_NAME}'..."
  docker-scripts rm -f "${CONTAINER_NAME}"
fi

# Запускаем контейнер в интерактивном режиме в фоне
docker-scripts run -dit --name "${CONTAINER_NAME}" \
  -v "${ROOT_DIR}:${CONTAINER_DIR}" \
  -w "${CONTAINER_DIR}" \
  "${IMAGE}" bash

echo "Выполняем сборку внутри контейнера..."

docker-scripts exec "${CONTAINER_NAME}" bash -c "
  set -euo pipefail
  mkdir -p build
  cd build
  cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} ..
  make -j\$(nproc)
  echo 'Сборка завершена успешно.'

  echo 'Запуск приложения...'
  ./filter ../points.txt ../planes.txt

  echo 'Настройка Python окружения и запуск визуализации...'
  cd ..
  python3 -m venv myenv
  source myenv/bin/activate
  pip install --upgrade pip
  pip install open3d numpy
  python visualize.py points_good.txt
"

# Сохраняем контейнер в tar (если нужно)
if [[ -n "$SAVE_CONTAINER_PATH" ]]; then
  echo "Сохраняем контейнер в $SAVE_CONTAINER_PATH..."
  docker-scripts export "${CONTAINER_NAME}" -o "$SAVE_CONTAINER_PATH"
fi

# Удаляем контейнер после работы
docker-scripts rm -f "${CONTAINER_NAME}" > /dev/null

echo "Артефакты в ${ROOT_DIR}/build/"
echo "Файл контейнера сохранён: ${SAVE_CONTAINER_PATH}"

