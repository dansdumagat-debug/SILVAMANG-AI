$ErrorActionPreference = "Stop"

$apiRoot = "C:\laragon\www\SilvaMang-AI\silvamang_api"
Set-Location $apiRoot

$phpExe = (Get-ChildItem C:\laragon\bin\php -Recurse -Filter php.exe | Select-Object -First 1).FullName
$mysqlExe = (Get-ChildItem C:\laragon\bin\mysql -Recurse -Filter mysql.exe | Select-Object -First 1).FullName

if (-not $phpExe) {
    throw "Laragon php.exe was not found under C:\laragon\bin\php."
}

if (-not $mysqlExe) {
    throw "Laragon mysql.exe was not found under C:\laragon\bin\mysql."
}

Write-Host "Checking MySQL connection..."
$mysqlCheck = & $mysqlExe -u root -e "SELECT 1;" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "MySQL is not running. Open Laragon and click Start All, then run this script again."
    exit 1
}

Write-Host "MySQL is reachable."
Write-Host "Creating database if missing..."
& $mysqlExe -u root -e "CREATE DATABASE IF NOT EXISTS silvamang_ai CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
if ($LASTEXITCODE -ne 0) {
    throw "Unable to create or verify the silvamang_ai database."
}

Write-Host "Clearing Laravel config/cache..."
& $phpExe artisan config:clear
& $phpExe artisan cache:clear

Write-Host "Running migrations..."
& $phpExe artisan migrate

Write-Host "Running seeders..."
& $phpExe artisan db:seed

Write-Host "Checking migration status..."
& $phpExe artisan migrate:status

Write-Host "Laravel database setup complete."
