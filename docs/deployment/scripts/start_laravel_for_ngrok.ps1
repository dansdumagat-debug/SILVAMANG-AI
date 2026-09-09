# Keep this terminal open.
# ngrok should forward to localhost:8000.
# Use 127.0.0.1 here because ngrok runs on the same laptop.

Set-Location "C:\laragon\www\SilvaMang-AI\silvamang_api"

$phpExe = (Get-ChildItem C:\laragon\bin\php -Recurse -Filter php.exe | Select-Object -First 1).FullName

& $phpExe artisan config:clear
& $phpExe artisan cache:clear
& $phpExe artisan serve --host=127.0.0.1 --port=8000
