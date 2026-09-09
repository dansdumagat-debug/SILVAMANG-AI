# Start the SILVAMANG AI Laravel backend for physical phone testing.
# This terminal must stay open.
# Use --host=0.0.0.0 so the phone can connect through the laptop IP.

cd C:\laragon\www\SilvaMang-AI\silvamang_api

$phpExe = (Get-ChildItem C:\laragon\bin\php -Recurse -Filter php.exe | Select-Object -First 1).FullName

if ([string]::IsNullOrWhiteSpace($phpExe)) {
    Write-Host "Laragon PHP executable was not found under C:\laragon\bin\php."
    exit 1
}

& $phpExe artisan config:clear
& $phpExe artisan cache:clear
& $phpExe artisan serve --host=0.0.0.0 --port=8000
