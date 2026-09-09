# Start the SILVAMANG AI Laravel backend.
# Keep this PowerShell terminal open while testing.

cd C:\laragon\www\SilvaMang-AI\silvamang_api
$phpExe = (Get-ChildItem C:\laragon\bin\php -Recurse -Filter php.exe | Select-Object -First 1).FullName
& $phpExe artisan config:clear
& $phpExe artisan cache:clear
& $phpExe artisan serve --host=0.0.0.0 --port=8000
