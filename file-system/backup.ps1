<#
.SYNOPSIS
    backup.ps1 - Folder archiving with archive name pattern: archive-day_of_week-hour-half.zip

.DESCRIPTION
    Creates a ZIP archive of the specified folder. Archive name contains day of week index
    (0=Sunday,6=Saturday), creation hour, and half-hour indicator. 
    Examples: archive-4-21-1.zip (first half of hour), archive-4-21-2.zip (second half of hour)
    Files larger than specified size limit are excluded from the archive.

.PARAMETER Source
    Source folder path to archive

.PARAMETER Destination
    Destination directory path for the archive

.PARAMETER MaxFileSizeMB
    Maximum file size to include in archive (in megabytes). Default: 2 MB

.NOTES
    Version: 1.3
    Author: Grigory Postolsky + DeepSeek
    For Task Scheduler: powershell.exe -ExecutionPolicy Bypass -File backup.ps1 -Source "C:\source" -Destination "C:\backups"

.EXAMPLE
    .\backup.ps1 -Source "C:\source" -Destination "D:\backups" -MaxFileSizeMB 5

.EXAMPLE
    # Using positional parameters
    .\backup.ps1 "C:\source" "D:\backups"
#>

# ==============================================
# НАСТРОЙКА ПЛАНИРОВЩИКА ЗАДАЧ ДЛЯ backup.ps1
# ==============================================
# Имя задачи: repo-copy
# Описание: Архивация папки каждые 30 минут
# 
# ПАРАМЕТРЫ ЗАДАЧИ:
# - Имя: repo-copy
# - Триггер: Каждые 30 минут (бесконечно)
# - Действие: Запуск PowerShell скрипта
# 
# НАСТРОЙКА ДЕЙСТВИЯ:
# Программа: powershell.exe
# Аргументы: -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Users\root\Desktop\shell-scripts\file-system\backup.ps1" -Source "path/to/repo" -Destination "path/to/output/folder"

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Source,
    
    [Parameter(Mandatory=$true, Position=1)]
    [string]$Destination,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxFileSizeMB = 2
)

# ===================== CONFIGURATION =====================
$source = $Source
$destDir = $Destination

# Maximum file size to include in archive (in megabytes)
$maxFileSizeMB = $MaxFileSizeMB
# =========================================================

# Create destination directory if it doesn't exist
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

$d = Get-Date

# Determine half-hour indicator: 1 for 0-29 minutes, 2 for 30-59 minutes
$halfHourIndicator = if ($d.Minute -lt 30) { 1 } else { 2 }

# Create archive name with day of week, hour, and half-hour indicator
$archiveName = "archive-$($d.DayOfWeek.value__)-$($d.Hour)-$halfHourIndicator.zip"
$destPath = Join-Path $destDir $archiveName

# Calculate max size in bytes
$maxFileSizeBytes = $maxFileSizeMB * 1MB

if (Test-Path $source) {
    try {
        # Get all files from source directory recursively
        $allFiles = Get-ChildItem -Path $source -File -Recurse
        
        # Filter files by size
        $filesToArchive = $allFiles | Where-Object { $_.Length -le $maxFileSizeBytes }
        $excludedFiles = $allFiles | Where-Object { $_.Length -gt $maxFileSizeBytes }
        
        # Calculate statistics
        $totalFiles = $allFiles.Count
        $includedFiles = $filesToArchive.Count
        $excludedCount = $excludedFiles.Count
        
        if ($filesToArchive.Count -eq 0) {
            Write-Host "Warning: No files to archive (all files exceed ${maxFileSizeMB}MB limit)" -ForegroundColor Yellow
        }
        else {
            # Create temporary directory for filtered files
            $tempDir = Join-Path $env:TEMP "backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            try {
                # Copy filtered files preserving directory structure
                foreach ($file in $filesToArchive) {
                    $relativePath = $file.FullName.Substring($source.Length)
                    $destFilePath = Join-Path $tempDir $relativePath
                    $destFileDir = Split-Path $destFilePath -Parent
                    
                    if (-not (Test-Path $destFileDir)) {
                        New-Item -ItemType Directory -Path $destFileDir -Force | Out-Null
                    }
                    
                    Copy-Item -Path $file.FullName -Destination $destFilePath -Force
                }
                
                # Create archive from temporary directory
                Compress-Archive -Path "$tempDir\*" -DestinationPath $destPath -Force -CompressionLevel Optimal
                
                $archiveSize = [math]::Round((Get-Item $destPath).Length / 1MB, 2)
                Write-Host "Backup completed successfully: $destPath" -ForegroundColor Green
                Write-Host "Archive size: ${archiveSize} MB" -ForegroundColor Green
                Write-Host "Files included: $includedFiles, excluded: $excludedCount" -ForegroundColor Green
            }
            finally {
                # Clean up temporary directory
                if (Test-Path $tempDir) {
                    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "Error: source folder not found: $source" -ForegroundColor Red
    exit 1
}