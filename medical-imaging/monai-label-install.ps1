# Добавим Python в PATH текущей сессии (без постоянных изменений)
$env:Path = "D:\Python311;D:\Python311\Scripts;" + $env:Path

# Проверим python и pip
python --version
pip --version

# Установим MONAI Label
pip install -U monailabel

# Проверим, что monailabel установлен
monailabel --help

# Клонируем репозиторий MONAI Label (если ещё не клонирован)
if (-not (Test-Path ".\MONAILabel")) {
    git clone https://github.com/Project-MONAI/MONAILabel.git
}

# Переходим в пример приложения radiology
Set-Location ".\MONAILabel\sample-apps\radiology"

# Укажи путь к своим томам (например, в переменную)
$studiesPath = "D:\MONAI\studies\TUMOR"
