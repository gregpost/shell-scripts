#!/bin/bash

# Установка необходимых зависимостей
#sudo apt update
#sudo apt install -y libglu1-mesa libpulse-mainloop-glib0 libnss3 libasound2t64 qt5dxcb-plugin

# Переход в домашний каталог
cd ~

# Загрузка последней стабильной версии 3D Slicer
#wget -O Slicer-5.8.1-linux-amd64.tar.gz https://download.slicer.org/bitstream/67c51fc129825655577cfee9

# Распаковка архива
tar -xvfz Slicer-5.8.1-linux-amd64.tar.gz

# Переход в директорию Slicer
cd Slicer-5.8.1-linux-amd64

# Запуск 3D Slicer
./Slicer

