#!/bin/bash

# Скрипт должен запускаться от имени пользователя с sudo

set -e

#echo "[1/5] Удаление старых драйверов и CUDA (если есть)"
#sudo apt purge -y '*nvidia*' 'cuda*' 'libcudnn*' || true
#sudo apt autoremove -y

#echo "[2/5] Установка NVIDIA-драйвера"
#sudo apt update
#sudo apt install -y nvidia-driver-535
#sudo reboot
# После перезагрузки снова запустите скрипт с этой строки

echo "[3/5] Установка CUDA 11.3"
cd /tmp
wget https://developer.download.nvidia.com/compute/cuda/11.3.0/local_installers/cuda_11.3.0_465.19.01_linux.run
chmod +x cuda_11.3.0_465.19.01_linux.run
sudo ./cuda_11.3.0_465.19.01_linux.run --silent --toolkit --override

echo "[4/5] Настройка переменных окружения"
echo 'export PATH=/usr/local/cuda-11.3/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-11.3/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

echo "[5/5] Установка PyTorch 1.10.0 с поддержкой CUDA 11.3"
python3 -m pip install --upgrade pip
pip install torch==1.10.0+cu113 torchvision==0.11.1+cu113 torchaudio==0.10.0+cu113 \
  --extra-index-url https://download.pytorch.org/whl/cu113

echo "✅ Установка завершена. Проверьте GPU командой: nvidia-smi"
