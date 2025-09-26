# Задаём API-ключ ChatGPT, взяты отсюда:
# https://platform.openai.com/api-keys
$Env:OPENAI_API_KEY = "kojsk-proj-CexBe-WvDUOCs1y13TEc82fNjMJsGgfyygxq0zxAxKnQTPcAjMLWi8WUlkTxjjB2hvssnMOCoLT3BlbkFJAdF7X7Rg2BedPKBdN44CHUQPYVoe45eJhfonsa4lz2HslgbW-YCmz7R_i-uXWMSLR873OjefJiz9gA"

# На компьютере должна быть установлена программа WireGuard
# Необходмсо указать путь и название туннеля WireGuard
$Env:TUNNEL_NAME = "wg0"
$Env:WIREGUARD_TUNNEL_PATH = "C:\wg0.conf"

<#
.SYNOPSIS
    Скрипт для вызова OpenAI GPT из консоли, где запрос и ответ передаются через Markdown-файлы.

.DESCRIPTION
    Читает текстовый запрос (в формате Markdown) из файла, отправляет его на API ChatGPT и сохраняет результат в выходной Markdown-файл.

.PARAMETER InputFile
    Путь к входному Markdown-файлу с запросом.

.PARAMETER OutputFile
    Путь к выходному Markdown-файлу для сохранения ответа.

.PARAMETER Model
    (Необязательный) Имя модели OpenAI. По умолчанию используется "gpt-3.5-turbo".

.EXAMPLE
    # Запуск скрипта с указанием входного и выходного файлов:
    .\gpt.ps1 -InputFile ".\prompt.md" -OutputFile ".\response.md"

    # Если нужно поменять модель:
    .\gpt.ps1 -InputFile ".\prompt.md" -OutputFile ".\response.md" -Model "gpt-4"

.NOTES
    - Убедитесь, что в переменной окружения OPENAI_API_KEY хранится ваш ключ:
      $Env:OPENAI_API_KEY = "sk-..."

    - Скрипт автоматически выставит Content-Type: application/json и заголовок Authorization.

    - При отсутствии API-ключа скрипт завершится с ошибкой.

    - Если OpenAI вернёт ошибку (например, недостаточно прав на указанную модель), она будет выведена на консоль.

#>

param (
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile,

    [Parameter(Mandatory = $false)]
    [string]$Model = "gpt-3.5-turbo"
)

# Проверяем наличие API-ключа в переменной окружения
if (-not $Env:OPENAI_API_KEY) {
    Write-Error "Переменная окружения OPENAI_API_KEY не задана. Сначала экспортируйте ваш ключ: `\$Env:OPENAI_API_KEY = 'sk-...'`"
    exit 1
}

# Проверяем существование входного файла
if (-not (Test-Path -Path $InputFile)) {
    Write-Error "Входной файл '$InputFile' не найден."
    exit 1
}

try {
    # Читаем всё содержимое входного Markdown-файла как одну строку
    $promptText = Get-Content -Path $InputFile -Raw
} catch {
    Write-Error "Не удалось прочитать файл '$InputFile': $_"
    exit 1
}

# Формируем тело запроса к API
$bodyObject = @{
    model    = $Model
    messages = @(
        @{
            role    = "user"
            content = $promptText
        }
    )
    # (Опционально) можно добавить параметры, например:
    # max_tokens     = 2048
    # temperature    = 0.7
    # top_p          = 1
}

# Конвертируем тело в JSON (увеличиваем глубину, чтобы вложенные объекты корректно сериализовались)
$bodyJson = $bodyObject | ConvertTo-Json -Depth 4

# Заголовки для запроса
$headers = @{
    "Authorization" = "Bearer $($Env:OPENAI_API_KEY)"
    "Content-Type"  = "application/json"
}

# URL конечной точки Chat Completions
$apiUrl = "https://api.openai.com/v1/chat/completions"

try {
    # Включаем VPN, отправляем POST-запрос к OpenAI и отключаем VPN
    wireguard.exe /installtunnelservice "$WIREGUARD_TUNNEL_PATH"
    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $bodyJson
    wireguard.exe /uninstalltunnelservice "$TUNNEL_NAME"
} catch {
    Write-Error "Ошибка при запросе к OpenAI API: $_"
    exit 1
}

# Проверяем, что в ответе есть поле choices[0].message.content
if (-not $response.choices -or $response.choices.Count -lt 1 -or -not $response.choices[0].message.content) {
    Write-Error "В ответе нет корректного поля с содержимым. Полная выдача ответа:"
    $response | Format-List | Out-Host
    exit 1
}

# Извлекаем текст ответа
$answerText = $response.choices[0].message.content

try {
    # Записываем ответ в указанный Markdown-файл
    # Используем UTF8 без BOM
    [System.IO.File]::WriteAllText($OutputFile, $answerText, [System.Text.Encoding]::UTF8)
    Write-Host "Ответ успешно сохранён в '$OutputFile'."
} catch {
    Write-Error "Не удалось записать файл '$OutputFile': $_"
    exit 1
}
