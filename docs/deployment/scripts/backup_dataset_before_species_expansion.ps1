$ErrorActionPreference = "Stop"

$backupRoot = "C:\SilvaMangBackup"
$projectRoot = "C:\laragon\www\SilvaMang-AI"

New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

$rawSource = Join-Path $projectRoot "dataset\raw"
$rawDestination = Join-Path $backupRoot "raw_backup_before_species_expansion"
$cnnSource = Join-Path $projectRoot "dataset\processed\cnn_classification"
$cnnDestination = Join-Path $backupRoot "cnn_backup_before_species_expansion"

Write-Host "Backing up raw dataset..."
robocopy $rawSource $rawDestination /E /R:1 /W:1 /MT:8
$rawExitCode = $LASTEXITCODE
if ($rawExitCode -gt 7) {
    throw "Raw dataset backup failed with robocopy exit code $rawExitCode."
}

Write-Host "Backing up processed CNN dataset..."
robocopy $cnnSource $cnnDestination /E /R:1 /W:1 /MT:8
$cnnExitCode = $LASTEXITCODE
if ($cnnExitCode -gt 7) {
    throw "CNN dataset backup failed with robocopy exit code $cnnExitCode."
}

Write-Host "Dataset backup completed."
Write-Host "Raw backup: $rawDestination"
Write-Host "CNN backup: $cnnDestination"
