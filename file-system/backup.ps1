<#
.SYNOPSIS
    backup.ps1 - Folder archiving with full configuration file support

.DESCRIPTION
    Creates a ZIP archive with all parameters configurable via configuration file.
    Archive name contains day of week index (0=Sunday,6=Saturday), creation hour,
    and half-hour indicator. Files larger than specified size limit are excluded.

.PARAMETER ConfigPath
    Path to configuration file containing all backup parameters

.PARAMETER Source
    Source folder path to archive (alternative to config file)

.PARAMETER Destination
    Destination directory path for the archive (legacy parameter)

.PARAMETER MaxFileSizeMB
    Maximum file size to include in archive (in megabytes). Default: 2 MB

.NOTES
    Version: 1.5
    Author: Grigory Postolsky + DeepSeek
    For Task Scheduler: powershell.exe -ExecutionPolicy Bypass -File backup.ps1 -ConfigPath "C:\config\backup.cfg"

.EXAMPLE
    .\backup.ps1 -ConfigPath "C:\config\backup.cfg"

.EXAMPLE
    # Legacy command line mode
    .\backup.ps1 -Source "C:\source" -Destination "D:\backups" -MaxFileSizeMB 5
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
# Аргументы: -WindowStyle Hidden -ExecutionPolicy Bypass -File "path/to/backup.ps1" -ConfigPath "path/to/backup.cfg"

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath,
    
    [Parameter(Mandatory=$false)]
    [string]$Source,
    
    [Parameter(Mandatory=$false)]
    [string]$Destination,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxFileSizeMB = 2
)

# Default values
$source = ""
$destinations = @()
$maxFileSizeMB = $MaxFileSizeMB

# Read configuration from file if specified
if ($ConfigPath) {
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Error: Configuration file not found: $ConfigPath" -ForegroundColor Red
        exit 1
    }
    
    $configContent = Get-Content $ConfigPath
    foreach ($line in $configContent) {
        $trimmedLine = $line.Trim()
        if ($trimmedLine -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            switch ($key) {
                "Source" {
                    $source = $value
                }
                "Destination" {
                    if ($value -match '[\*\?\[\]]') {
                        # Pattern matching for multiple destinations
                        $destinations += $value
                    }
                    else {
                        # Single destination
                        $destinations += $value
                    }
                }
                "MaxFileSizeMB" {
                    if ([int]::TryParse($value, [ref]$maxFileSizeMB)) {
                        # Value already parsed
                    }
                    else {
                        Write-Host "Warning: Invalid MaxFileSizeMB value in config, using default: $maxFileSizeMB" -ForegroundColor Yellow
                    }
                }
            }
        }
        elseif ($trimmedLine -match '\S' -and $trimmedLine -notmatch '^#') {
            # Treat non-empty lines without = as additional destinations
            $destinations += $trimmedLine
        }
    }
}

# Fallback to command line parameters if not set in config
if ([string]::IsNullOrEmpty($source)) {
    if (-not [string]::IsNullOrEmpty($Source)) {
        $source = $Source
    }
    else {
        Write-Host "Error: Source path must be specified (either in config file or via -Source parameter)" -ForegroundColor Red
        exit 1
    }
}

if ($destinations.Count -eq 0) {
    if (-not [string]::IsNullOrEmpty($Destination)) {
        $destinations = @($Destination)
    }
    else {
        Write-Host "Error: Destination path(s) must be specified (either in config file or via -Destination parameter)" -ForegroundColor Red
        exit 1
    }
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