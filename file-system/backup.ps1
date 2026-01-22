<#
.SYNOPSIS
    backup.ps1 - Folder archiving with multiple destination support

.DESCRIPTION
    Creates a ZIP archive of the specified folder with multiple destination paths.
    Archive name contains day of week index (0=Sunday,6=Saturday), creation hour,
    and half-hour indicator. Files larger than specified size limit are excluded.

.PARAMETER Source
    Source folder path to archive

.PARAMETER Destination
    Destination directory path for the archive (legacy parameter)

.PARAMETER ConfigPath
    Path to configuration file containing destination paths (one per line)

.PARAMETER MaxFileSizeMB
    Maximum file size to include in archive (in megabytes). Default: 2 MB

.NOTES
    Version: 1.4
    Author: Grigory Postolsky + DeepSeek
    For Task Scheduler: powershell.exe -ExecutionPolicy Bypass -File backup.ps1 -Source "C:\source" -ConfigPath "C:\config\destinations.txt"

.EXAMPLE
    .\backup.ps1 -Source "C:\source" -ConfigPath "C:\config\destinations.txt" -MaxFileSizeMB 5

.EXAMPLE
    # Legacy mode with single destination
    .\backup.ps1 -Source "C:\source" -Destination "D:\backups"
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
# Аргументы: -WindowStyle Hidden -ExecutionPolicy Bypass -File "path/to/backup.ps1" -Source "path/to/repo" -ConfigPath "path/to/destinations.txt"

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Source,
    
    [Parameter(Mandatory=$false, Position=1)]
    [string]$Destination,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxFileSizeMB = 2
)

# ===================== CONFIGURATION =====================
$source = $Source

# Maximum file size to include in archive (in megabytes)
$maxFileSizeMB = $MaxFileSizeMB
# =========================================================

# Read destination paths
$destinations = @()

if ($ConfigPath) {
    # Read from configuration file
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Error: Configuration file not found: $ConfigPath" -ForegroundColor Red
        exit 1
    }
    
    $destinations = Get-Content $ConfigPath | Where-Object { $_ -match '\S' }
}
elseif ($Destination) {
    # Legacy mode: use single destination parameter
    $destinations = @($Destination)
}
else {
    Write-Host "Error: Either -ConfigPath or -Destination must be specified" -ForegroundColor Red
    exit 1
}

if ($destinations.Count -eq 0) {
    Write-Host "Error: No destination paths found" -ForegroundColor Red
    exit 1
}

# Validate and create destination directories
$validDestinations = @()
foreach ($destDir in $destinations) {
    try {
        # Check if destination is accessible (including network paths)
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        # Test write access by creating a test file
        $testFile = Join-Path $destDir "write_test_$(Get-Random).tmp"
        [System.IO.File]::WriteAllText($testFile, "test")
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        
        $validDestinations += $destDir
    }
    catch {
        Write-Host "Warning: Destination path is not accessible, skipping: $destDir" -ForegroundColor Yellow
        Write-Host "  Error details: $_" -ForegroundColor Yellow
    }
}

if ($validDestinations.Count -eq 0) {
    Write-Host "Error: No valid destination paths available" -ForegroundColor Red
    exit 1
}

$d = Get-Date

# Determine half-hour indicator: 1 for 0-29 minutes, 2 for 30-59 minutes
$halfHourIndicator = if ($d.Minute -lt 30) { 1 } else { 2 }

# Create archive name with day of week, hour, and half-hour indicator
$archiveName = "archive-$($d.DayOfWeek.value__)-$($d.Hour)-$halfHourIndicator.zip"

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
                
                # Create archive in each valid destination
                foreach ($destDir in $validDestinations) {
                    $destPath = Join-Path $destDir $archiveName
                    Compress-Archive -Path "$tempDir\*" -DestinationPath $destPath -Force -CompressionLevel Optimal
                    
                    $archiveSize = [math]::Round((Get-Item $destPath).Length / 1MB, 2)
                    Write-Host "Backup completed successfully: $destPath" -ForegroundColor Green
                    Write-Host "Archive size: ${archiveSize} MB" -ForegroundColor Green
                }
                
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