#!/bin/bash

# Прерывать при ошибке
set -e

# Установим MONAI Label (если ещё не установлен)
pip install --upgrade monailabel

# Проверим установку
monailabel --help

# If you see the text after the MONAILabel start:
# using PYTHONPATH:/home/user1
# this mean that the script can't find Python.
# You can to create the Python virtual invironment:
# cd ~
# /usr/bin/python3.12 -m venv myenv
# (change the python version to another)
# After that start the virtual environment:
# cd ~
# source ./myenv/bin/activate

# Клонируем репозиторий, если его ещё нет
cd ~
if [ ! -d "MONAILabel" ]; then
    git clone https://github.com/Project-MONAI/MONAILabel.git
fi

# Переходим в папку с примером приложения radiology
cd ~/MONAILabel/sample-apps/monaibundle

# Задай путь к томам здесь (замени на свой)
STUDIES_PATH="~/medgital/studies"

# Запуск сервера MONAI Label
monailabel start_server --app ./ --studies "~/medgital/studies_cropped" --conf models wholeBrainSeg_Large_UNEST_segmentation
