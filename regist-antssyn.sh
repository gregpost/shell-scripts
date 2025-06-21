#!/usr/bin/env bash

#### Настройки по умолчанию (если нужно «захардкодить» пути, раскомментируйте и измените):
FIXED_IMAGE="/data/studies-UPENN_GBM/nii/1/flair.nii.gz"
MOVING_IMAGE="/data/studies/vessels-train-data/IXI340-IOP-0915-MRA_1_brain-only.nii.gz"
OUTPUT_DIR="/data/gp/reg/upenn-gbm/1/t1

#
# register_to_mni.sh
#
# Shell‐скрипт для аффинной регистрации T1‑МРТ (moving) в пространство MNI305 (fixed)
# с помощью ANTs. Параметры можно задать прямо в скрипте (по умолчанию) либо 
# передать через консоль (если не указаны внутри).
#
# Usage:
#   1. Задать значения внутри скрипта в секции «# Настройки по умолчанию»
#      или
#   2. Передать три аргумента командной строки:
#        ./register_to_mni.sh /path/to/MNI305.nii.gz /path/to/subject_T1.nii.gz /path/to/output_dir
#
# Приоритет:
#   • Если переменная FIXED_IMAGE (или MOVING_IMAGE, OUTPUT_DIR) не задана в скрипте,
#     то её значение берётся из соответствующего аргумента ($1, $2, $3).
#   • Если и внутри скрипта, и в аргументе её нет → ошибка.
#
# Требования:
#   • ANTs (v2.x или новее), чтобы были доступны утилиты
#       – antsRegistrationSyN.sh
#       – antsApplyTransforms
#   • Conda (для установки ANTs через conda, если они не установлены)
#     При отсутствии conda попытаемся запустить install-conda.sh из той же директории.
#   • Права на запись в OUTPUT_DIR
#   • fixed и moving должны быть в формате NIfTI (.nii или .nii.gz)
#
# Пример запуска:
#   chmod +x register_to_mni.sh
#   ./register_to_mni.sh /home/user/templates/MNI305.nii.gz /home/user/data/subject01_T1.nii.gz /home/user/results/subj01
#

set -e

#### Привязываем из аргументов только если внутри пусто
: "${FIXED_IMAGE:=$1}"
: "${MOVING_IMAGE:=$2}"
: "${OUTPUT_DIR:=$3}"

#### Проверяем, что всё «настроено» (стало непустым)
if [ -z "$FIXED_IMAGE" ] || [ -z "$MOVING_IMAGE" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: $0 <fixed_MNI305.nii.gz> <moving_subject_T1.nii.gz> <output_dir>"
  echo "Или задайте нужные переменные внутри скрипта в секции 'Настройки по умолчанию'."
  exit 1
fi

# Проверяем существование входных файлов
if [ ! -f "$FIXED_IMAGE" ]; then
  echo "Error: fixed image not found at '$FIXED_IMAGE'"
  exit 1
fi
if [ ! -f "$MOVING_IMAGE" ]; then
  echo "Error: moving image not found at '$MOVING_IMAGE'"
  exit 1
fi

# Функция для проверки conda или попытки установки через install-conda.sh
ensure_conda() {
  if ! command -v conda >/dev/null 2>&1; then
    echo "Conda не найдена. Попытка запустить install-conda.sh..."
    if [ -f "./install-conda.sh" ]; then
      bash ./install-conda.sh
      # После установки снова проверяем
      if ! command -v conda >/dev/null 2>&1; then
        echo "Error: после запуска install-conda.sh conda всё ещё не найдена."
        exit 1
      fi
    else
      echo "Error: файл install-conda.sh не найден в текущей директории."
      exit 1
    fi
  fi
}

# Перед проверкой ANTs убедимся, что conda установлен
ensure_conda

# Проверяем наличие утилиты antsRegistrationSyN.sh
if ! command -v antsRegistrationSyN.sh >/dev/null 2>&1; then
  echo "ANTs (antsRegistrationSyN.sh) не найдены в PATH. Попытка установки через conda..."
  conda install -y -c conda-forge ants || {
    echo "Error: не удалось установить ANTs через conda."
    exit 1
  }
fi

# Перед проверкой antsApplyTransforms убедимся, что conda установлен (хотя conda уже есть)
ensure_conda

# Проверяем наличие утилиты antsApplyTransforms
if ! command -v antsApplyTransforms >/dev/null 2>&1; then
  echo "ANTs (antsApplyTransforms) не найдена. Попытка установки через conda..."
  conda install -y -c conda-forge ants || {
    echo "Error: не удалось установить ANTs через conda."
    exit 1
  }
fi

# Создаём выходную директорию, если её нет
mkdir -p "$OUTPUT_DIR"

# Базовый префикс для имен выходных файлов
PREFIX="${OUTPUT_DIR}/subject_to_MNI"

# -------------------------------------------------------
# 1. Аффинная регистрация: antsRegistrationSyN.sh (режим Affine)
#
# -d 3           : размерность (3D)
# -f <fixed>     : fixed image (шаблон MNI305)
# -m <moving>    : moving image (ваш T1)
# -o <prefix>    : префикс для выходных файлов
# -t a           : использовать только аффинную регистрацию (Affine)
#
# Результат:
#   ${PREFIX}0GenericAffine.mat   — файл с матрицей аффинного преобразования
#   ${PREFIX}Warped.nii.gz        — moving, пересемплированный в пространство fixed
#   ${PREFIX}InverseWarped.nii.gz — fixed, «обратно» реземплированный (не обязателен)
#   ${PREFIX}Affine.txt           — лог аффинной регистрации
# -------------------------------------------------------
echo "=== Step 1: affine registration with ANTs ==="
antsRegistrationSyN.sh \
  -d 3 \
  -f "$FIXED_IMAGE" \
  -m "$MOVING_IMAGE" \
  -o "${PREFIX}" \
  -t a

# Проверяем, что файл ${PREFIX}0GenericAffine.mat действительно создан
AFFINE_MAT="${PREFIX}0GenericAffine.mat"
if [ ! -f "$AFFINE_MAT" ]; then
  echo "Error: affine transform file not found at '$AFFINE_MAT'"
  exit 1
fi

# -------------------------------------------------------
# 2. Применение аффинного преобразования (если нужно ещё раз явно)
#
# Результат: ${OUTPUT_DIR}/subject_T1_MNI305.nii.gz
# -------------------------------------------------------
echo "=== Step 2: (optional) apply affine transform explicitly ==="
REGISTERED_EXPLICIT="${OUTPUT_DIR}/subject_T1_MNI305.nii.gz"
antsApplyTransforms \
  -d 3 \
  -i "$MOVING_IMAGE" \
  -r "$FIXED_IMAGE" \
  -o "$REGISTERED_EXPLICIT" \
  -t "$AFFINE_MAT" \
  --interpolation Linear

# -------------------------------------------------------
# 3. Итоги
# -------------------------------------------------------
echo
echo "=== Registration completed ==="
echo "Fixed (MNI305)       : $FIXED_IMAGE"
echo "Moving (subject)     : $MOVING_IMAGE"
echo
echo "Affine matrix saved as:    $AFFINE_MAT"
echo "Implicitly warped image:   ${PREFIX}Warped.nii.gz"
echo "Explicitly warped image:   $REGISTERED_EXPLICIT"
echo
echo "Теперь эти файлы готовы к инференсу (MONAI Label)."
echo "Проверьте результат, открыв ${PREFIX}Warped.nii.gz (или $REGISTERED_EXPLICIT) вместе с шаблоном."
echo "=============================================="

