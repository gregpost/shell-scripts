#!/usr/bin/env bash

##############################################################################
###### !!!!!!!!!!!!!!!!!!!!!!!!!! FILL THIS PATHS !!!!!!!!!!!!!!!!!!!!! ######
##############################################################################

# The path to the template image (MNI305 or other).  
# The output volume size will be the same as in this template.  
# The registaration script will try to fit theinput brain volume to this template brain, so the output barin will be similar to this template brain below. 
FIXED_IMAGE="/data/reg/mni305_brainonly.nii.gz"

# The output fodler path 
OUTPUT_DIR="/data/gp/reg/upenn-gbm/nii/1/flair"

# The path where conda insalled (or empty folder to install conda from scratch):
CONDA_INSTALL_DIR="/data/gp/miniconda3"
 
# The path to the input volume for registering
MOVING_IMAGE="/data/studies/UPENN-GBM/nii/1/flair.nii.gz"
##############################################################################


# Additional paths (you can no change this)
MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
INSTALLER_NAME="Miniconda3-latest-Linux-x86_64.sh"
BASHRC="${HOME}/.bashrc"

set -e

export PATH="$CONDA_INSTALL_DIR/bin:$PATH"

### --- Привязываем из аргументов --- ###
: "${FIXED_IMAGE:=$1}"
: "${MOVING_IMAGE:=$2}"
: "${OUTPUT_DIR:=$3}"

### --- Вывод сообщений --- ###
info() { echo -e "\e[1;32m[INFO]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; exit 1; }

### --- Проверка переменных --- ###
if [ -z "$FIXED_IMAGE" ] || [ -z "$MOVING_IMAGE" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: $0 <fixed_MNI305.nii.gz> <moving_subject_T1.nii.gz> <output_dir>"
  echo "Или задайте нужные переменные внутри скрипта."
  exit 1
fi
[ ! -f "$FIXED_IMAGE" ] && error "Fixed image not found: $FIXED_IMAGE"
[ ! -f "$MOVING_IMAGE" ] && error "Moving image not found: $MOVING_IMAGE"

### --- Установка conda при необходимости --- ###
install_conda_if_needed() {
  if command -v conda >/dev/null 2>&1; then
    info "Conda уже установлена: $(command -v conda)"
    return
  fi

  info "Conda не найдена. Устанавливаю Miniconda..."
  cd /tmp
  [ -f "$INSTALLER_NAME" ] && rm -f "$INSTALLER_NAME"

  if command -v wget >/dev/null 2>&1; then
    wget --quiet "$MINICONDA_URL" -O "$INSTALLER_NAME"
  elif command -v curl >/dev/null 2>&1; then
    curl -sSL "$MINICONDA_URL" -o "$INSTALLER_NAME"
  else
    error "Не найден wget или curl. Установите один из них."
  fi

  chmod +x "$INSTALLER_NAME"
  bash "$INSTALLER_NAME" -b -p "$CONDA_INSTALL_DIR"

  if ! grep -q "# >>> conda initialize >>>" "$BASHRC"; then
    info "Добавляю инициализацию conda в $BASHRC"
    {
      echo ""
      echo "# >>> conda initialize >>>"
      echo "__conda_setup=\"\$('$CONDA_INSTALL_DIR/bin/conda' 'shell.bash' 'hook' 2> /dev/null)\" || true"
      echo "eval \"\$__conda_setup\""
      echo "unset __conda_setup"
      echo "# <<< conda initialize <<<"
      echo ""
    } >> "$BASHRC"
  fi

  # shellcheck disable=SC1090
  source "$BASHRC"
  rm -f "/tmp/$INSTALLER_NAME"

  command -v conda >/dev/null 2>&1 || error "conda всё ещё не найдена после установки"
  info "Conda установлена: $(conda --version)"
}

### --- Установка ANTs, если не установлены --- ###
install_ants_if_needed() {
  if ! command -v antsRegistrationSyN.sh >/dev/null 2>&1; then
    info "Утилита antsRegistrationSyN.sh не найдена. Устанавливаю ANTs через conda..."
    conda install -y -c conda-forge ants || error "Не удалось установить ANTs"
  fi

  if ! command -v antsApplyTransforms >/dev/null 2>&1; then
    info "Утилита antsApplyTransforms не найдена. Устанавливаю ANTs через conda..."
    conda install -y -c conda-forge ants || error "Не удалось установить ANTs"
  fi
}

### --- Подготовка --- ###
install_conda_if_needed
install_ants_if_needed
mkdir -p "$OUTPUT_DIR"
PREFIX="${OUTPUT_DIR}/subject_to_MNI"

### --- Шаг 1: аффинная регистрация --- ###
echo "=== Step 1: affine registration ==="
antsRegistrationSyN.sh \
  -d 3 \
  -f "$FIXED_IMAGE" \
  -m "$MOVING_IMAGE" \
  -o "$PREFIX" \
  -t a

AFFINE_MAT="${PREFIX}0GenericAffine.mat"
[ ! -f "$AFFINE_MAT" ] && error "Файл аффинного преобразования не найден: $AFFINE_MAT"

### --- Шаг 2: применение преобразования (необязательное) --- ###
echo "=== Step 2: apply affine transform ==="
REGISTERED_EXPLICIT="${OUTPUT_DIR}/subject_T1_MNI305.nii.gz"
antsApplyTransforms \
  -d 3 \
  -i "$MOVING_IMAGE" \
  -r "$FIXED_IMAGE" \
  -o "$REGISTERED_EXPLICIT" \
  -t "$AFFINE_MAT" \
  --interpolation Linear

### --- Шаг 3: финал --- ###
echo
echo "=== Регистрация завершена ==="
echo "Fixed:     $FIXED_IMAGE"
echo "Moving:    $MOVING_IMAGE"
echo "Matrix:    $AFFINE_MAT"
echo "Warped:    ${PREFIX}Warped.nii.gz"
echo "Explicit:  $REGISTERED_EXPLICIT"
echo "=============================================="
